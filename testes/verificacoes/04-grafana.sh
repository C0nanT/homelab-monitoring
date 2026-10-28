# shellcheck shell=bash
# Carregado pelo testes/smoke.sh; usa as funções de testes/lib.sh.
# Grafana provisionado: saudável, só no loopback, exige a senha do .env, fonte
# de dados e os 3 painéis existem, e os painéis principais têm dados com o
# alvo falso (consultas feitas pelo próprio Grafana, em /api/ds/query).
#
# Variáveis (smoke.sh): GRAFANA_URL, PORTA_GRAFANA, GRAFANA_SENHA_ADMIN.

secao "Grafana: saúde, acesso e loopback"

grafana_saudavel() {
  [ "$(curl -sf --max-time 5 "$GRAFANA_URL/api/health" | jq -r '.database')" = ok ]
}
if esperar_ate 60 grafana_saudavel; then
  ok "Grafana saudável pela API (/api/health: database ok)"
else
  falha "Grafana saudável pela API em 60s" "veja: docker compose logs grafana"
fi

# As funções abaixo chamam o grafana-api.sh (GRAFANA_URL e GRAFANA_SENHA_ADMIN
# da pilha de teste vêm do ambiente) e também são usadas por 06-loki.sh,
# 07-painel-logs.sh e 98-loki-fora.sh (carregados depois deste arquivo).

# fonte_saudavel UID -> sucesso se o Grafana testa a fonte de dados com OK.
fonte_saudavel() {
  "$RAIZ/grafana-api.sh" GET "/api/datasources/uid/$1/health" |
    jq -e '.status=="OK"' >/dev/null
}

# grafana_ds_query CORPO_JSON -> resposta de /api/ds/query (a consulta que um
# painel faz, executada pelo próprio Grafana).
grafana_ds_query() {
  "$RAIZ/grafana-api.sh" POST /api/ds/query "$1"
}

# grafana_loki MODO EXPRESSAO -> resposta do Grafana para uma consulta LogQL
# na fonte loki (MODO: range ou instant), na última hora.
grafana_loki() {
  grafana_ds_query "$(jq -n --arg m "$1" --arg e "$2" \
    '{queries:[{refId:"A",datasource:{type:"loki",uid:"loki"},expr:$e,queryType:$m,maxLines:100}],from:"now-1h",to:"now"}')"
}

afirmar "login com a senha do .env funciona" "$RAIZ/grafana-api.sh" GET /api/org
afirmar "admin/admin NÃO funciona (senha vem do .env)" \
  bash -c '! curl -sf --max-time 10 -u admin:admin "$1/api/org"' _ "$GRAFANA_URL"
afirmar "API sem credenciais é recusada (401)" \
  test "$(curl -s -o /dev/null -w '%{http_code}' --max-time 10 "$GRAFANA_URL/api/datasources")" = 401

PORTAS_GRAFANA="$(pilha port grafana 3000 2>/dev/null)"
afirmar "porta 3000 publicada apenas em 127.0.0.1" \
  bash -c 'printf "%s\n" "$1" | grep -q "^127\.0\.0\.1:" && ! printf "%s\n" "$1" | grep -qE "^(0\.0\.0\.0|\[::\]|::):"' _ "$PORTAS_GRAFANA"

if [ -z "${IP_LAN:-}" ] || [ "${IP_LAN#127.}" != "$IP_LAN" ]; then
  echo "  AVISO sem IP não-loopback nesta máquina; verificação de rede do Grafana pulada"
else
  afirmar "Grafana NÃO responde em $IP_LAN (IP não-loopback do PC)" \
    bash -c '! curl -s --max-time 3 "http://$1:$2/api/health"' _ "$IP_LAN" "$PORTA_GRAFANA"
fi

secao "Grafana: fonte de dados e painéis provisionados"

DS_JSON="$("$RAIZ/grafana-api.sh" GET /api/datasources || echo '[]')"
afirmar "fonte de dados Prometheus (uid prometheus) existe" \
  test "$(jq -r '[.[]|select(.uid=="prometheus" and .type=="prometheus")]|length' <<<"$DS_JSON")" = 1
afirmar "fonte de dados Prometheus é a padrão" \
  test "$(jq -r '[.[]|select(.uid=="prometheus")|.isDefault]|first' <<<"$DS_JSON")" = true
afirmar "fonte de dados é provisionada (somente leitura na interface)" \
  test "$(jq -r '[.[]|select(.uid=="prometheus")|.readOnly]|first' <<<"$DS_JSON")" = true
afirmar "Grafana testa a fonte de dados com sucesso" fonte_saudavel prometheus

PAINEIS_JSON="$("$RAIZ/grafana-api.sh" GET '/api/search?type=dash-db' || echo '[]')"
for titulo in "Traefik" "Node Exporter Full" "Sites"; do
  afirmar "painel '$titulo' existe" \
    test "$(jq -r --arg t "$titulo" '[.[]|select(.title|startswith($t))]|length' <<<"$PAINEIS_JSON")" -ge 1
done

secao "Grafana: painéis principais mostram dados"

# painel_expr ARQUIVO TITULO [N] -> expressão da N-ésima consulta (padrão 1) do
# painel (em qualquer nível, inclusive dentro de linhas recolhidas), com as
# variáveis do painel trocadas pelos valores do alvo falso.
painel_expr() {
  jq -r --arg t "$2" --argjson n "${3:-0}" \
    '[.panels[]|., (.panels // [])[]]|map(select(.title==$t))|first|.targets[$n].expr' \
    "$RAIZ/grafana/dashboards/$1" |
    sed -e 's/\$__rate_interval/1m/g' -e 's/\$interval/1m/g' \
      -e 's/\$service//g' -e 's/\$entrypoint/.*/g' \
      -e 's/\$job/node/g' -e 's/\$node\b/tunel:9100/g'
}

# grafana_series EXPRESSAO -> quantidade de séries que o Grafana recebe do
# Prometheus (consulta instantânea em /api/ds/query).
grafana_series() {
  grafana_ds_query "$(jq -n --arg e "$1" '{queries:[{refId:"A",datasource:{type:"prometheus",uid:"prometheus"},expr:$e,instant:true,range:false}],from:"now-5m",to:"now"}')" |
    jq -r '[.results.A.frames[]?|(.data.values[1] // [])|length]|add // 0'
}

# tem_series EXPRESSAO -> sucesso se o Grafana recebe ao menos 1 série; guarda
# a quantidade em SERIES.
SERIES=0
tem_series() {
  SERIES="$(grafana_series "$1")"
  [ "${SERIES:-0}" -ge 1 ]
}

# tem_dados DESCRICAO EXPRESSAO
tem_dados() {
  local desc="$1" expr="$2"
  if [ -z "$expr" ] || [ "$expr" = null ]; then
    falha "$desc" "painel não encontrado no JSON"
    return 1
  fi
  # rate() precisa de 2 coletas (5s cada no smoke): tenta por até 60s.
  if esperar_ate 60 tem_series "$expr"; then
    ok "$desc ($SERIES série(s))"
  else
    falha "$desc" "sem dados (No data) para: $expr"
    return 1
  fi
}

# Sites (consultas escritas sem variáveis).
for titulo in "Sites no ar" "Latência por site" "Latência do TLS" "Status HTTP" \
  "Dias até vencer o certificado (blackbox)" "Dias até vencer o certificado (Traefik)"; do
  tem_dados "Sites: $titulo" "$(painel_expr sites.json "$titulo")"
done

# Traefik: painéis da comunidade + os acrescentados (5xx e certificados).
for titulo in "Requests per Entrypoint" "Top slow services" "Most requested services" \
  "5xx over \$interval" "Taxa de 5xx por serviço" "Dias até vencer o certificado"; do
  tem_dados "Traefik: $titulo" "$(painel_expr traefik.json "$titulo")"
done

# Host (node exporter).
for titulo in "CPU Busy" "RAM Used" "Root FS Used" "Uptime" "Network Traffic Basic"; do
  tem_dados "Host: $titulo" "$(painel_expr node-exporter-full.json "$titulo")"
done
