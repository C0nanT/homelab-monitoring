# shellcheck shell=bash
# Carregado pelo testes/smoke.sh; usa as funções de testes/lib.sh, de
# 04-grafana.sh (grafana_api, grafana_loki) e de 06-loki.sh (afirmar_linhas),
# e as linhas que o 06 injetou. Roda ANTES do 98 (que derruba o Loki falso).
# O painel Logs existe e as consultas DELE (lidas do JSON, com as variáveis
# trocadas pelo site escolhido) devolvem dados só do site escolhido.

secao "Painel Logs: provisionado e consultas por site"

PAINEL_LOGS=logs.json
PAINEIS_LOGS="$(grafana_api '/api/search?type=dash-db' || echo '[]')"
afirmar "painel 'Logs' (uid homelab-logs) existe" \
  test "$(jq -r '[.[]|select(.uid=="homelab-logs" and .title=="Logs")]|length' <<<"$PAINEIS_LOGS")" = 1
for uid in homelab-sites "$(jq -r '[.[]|select(.title=="Traefik")|.uid]|first' <<<"$PAINEIS_LOGS")"; do
  afirmar "painel $uid tem link no topo para o painel Logs" \
    test "$(grafana_api "/api/dashboards/uid/$uid" | jq -r '[.dashboard.links[]?|select(.url|test("/d/homelab-logs"))]|length')" -ge 1
done
afirmar "variável 'site' do painel Logs tem conan-torres, bbcontainer e a borda (traefik)" \
  test "$(jq -r '[.templating.list[]|select(.name=="site")|.query]|first' "$RAIZ/grafana/dashboards/$PAINEL_LOGS")" = "conan-torres,bbcontainer,traefik"
afirmar "painel Logs tem a variável de busca 'busca'" \
  test "$(jq -r '[.templating.list[]|select(.name=="busca")]|length' "$RAIZ/grafana/dashboards/$PAINEL_LOGS")" = 1
afirmar "a busca entra no painel só entre crases (aspas na busca não quebram a consulta)" \
  test "$(jq -r '[.panels[].targets[]?.expr|select(test("[$]busca"))|select(test("`[$]busca`")|not)]|length' "$RAIZ/grafana/dashboards/$PAINEL_LOGS")" = 0
afirmar "as consultas de logs do painel Logs usam a fonte loki" \
  test "$(jq -r '[.panels[].targets[]?|select(.expr|test("projeto="))|select(.datasource.uid!="loki")]|length' "$RAIZ/grafana/dashboards/$PAINEL_LOGS")" = 0

# logs_expr TITULO N SITE [BUSCA] -> consulta N (0-based) do painel, com as
# variáveis trocadas como o Grafana faz: valor cru, sem escape (a fonte Loki
# não escapa variável de valor único; por isso a busca fica entre crases no
# painel), e $__auto por 1h.
logs_expr() {
  jq -r --arg t "$1" --argjson n "$2" --arg site "$3" --arg busca "${4:-}" \
    '[.panels[]|select(.title==$t)]|first|.targets[$n].expr
     | gsub("\\$site"; $site) | gsub("\\$busca"; $busca) | gsub("\\$__auto"; "1h")' \
    "$RAIZ/grafana/dashboards/$PAINEL_LOGS"
}

# logs_total EXPRESSAO -> soma dos valores de uma consulta de métrica (1h).
logs_total() {
  grafana_loki instant "$1" |
    jq -r '[.results.A.frames[]?|(.data.values[1] // [])[]]|add // 0'
}
total_igual() { # expressão esperado
  [ "$(logs_total "$1")" = "$2" ]
}

# Logs da aplicação, por site e com busca de texto.
afirmar_linhas "Logs da aplicação: site conan-torres mostra só as linhas dele" \
  "$(logs_expr 'Logs da aplicação' 0 conan-torres)" "smoke-conan-web smoke-conan-erro" "smoke-bb-app smoke-traefik-acme DownstreamStatus"
afirmar_linhas "Logs da aplicação: site bbcontainer mostra só as linhas dele" \
  "$(logs_expr 'Logs da aplicação' 0 bbcontainer)" "smoke-bb-app" "smoke-conan-web smoke-conan-erro"
afirmar_linhas "Logs da aplicação: a borda (traefik) mostra o log do Traefik sem o log de acesso nem o socket-proxy" \
  "$(logs_expr 'Logs da aplicação' 0 traefik)" "smoke-traefik-acme" "DownstreamStatus smoke-conan-web smoke-socket-proxy"
afirmar_linhas "Logs da aplicação: busca de texto 'Error' filtra" \
  "$(logs_expr 'Logs da aplicação' 0 conan-torres Error)" "smoke-conan-erro" "smoke-conan-web"
afirmar_linhas "Logs da aplicação: busca com aspas (msg=\"smoke-traefik-acme) funciona" \
  "$(logs_expr 'Logs da aplicação' 0 traefik 'msg="smoke-traefik-acme')" "smoke-traefik-acme" -

# Log de acesso do site.
afirmar_linhas "Log de acesso: site conan-torres mostra o 200 dele (método, caminho, ClientHost, duração em ms)" \
  "$(logs_expr 'Log de acesso' 0 conan-torres)" "200 GET /ofertas 203.0.113.7 1.2ms" "502 /pedido 203.0.113.8"
afirmar_linhas "Log de acesso: site conan-torres inclui o router do www (conan-torres-www)" \
  "$(logs_expr 'Log de acesso' 0 conan-torres)" "301 GET /contato 203.0.113.9 0.8ms" -
afirmar_linhas "Log de acesso: site bbcontainer mostra o 502 dele" \
  "$(logs_expr 'Log de acesso' 0 bbcontainer)" "502 POST /pedido 203.0.113.8" "/ofertas 203.0.113.7 /contato 203.0.113.9"
afirmar_linhas "Log de acesso: busca de texto por caminho filtra" \
  "$(logs_expr 'Log de acesso' 0 bbcontainer pedido)" "/pedido" "/ofertas"
afirmar_linhas "Log de acesso: busca com aspas (\"RequestPath\":\"/contato) funciona" \
  "$(logs_expr 'Log de acesso' 0 conan-torres '"RequestPath":"/contato')" "/contato" "/ofertas"

# Linhas de erro ao longo do tempo: A = stderr, B = texto "error" em stdout.
afirmar "Erros: conan-torres tem 1 linha de erro (stderr)" \
  esperar_ate 30 total_igual "$(logs_expr 'Linhas de erro' 0 conan-torres)" 1
afirmar "Erros: bbcontainer tem 0 linhas de erro" \
  test "$(logs_total "$(logs_expr 'Linhas de erro' 0 bbcontainer)")" = 0
afirmar "Erros: a borda (traefik) tem 1 linha de erro, sem contar o socket-proxy" \
  esperar_ate 30 total_igual "$(logs_expr 'Linhas de erro' 0 traefik)" 1

# Respostas por classe de status (A=2xx, B=3xx, C=4xx, D=5xx) a partir do acesso.
# status_conferem SITE "2xx 3xx 4xx 5xx" -> totais de cada classe batem.
status_conferem() {
  local n=0 esperado
  for esperado in $2; do
    [ "$(logs_total "$(logs_expr 'Respostas por classe de status' "$n" "$1")")" = "$esperado" ] ||
      return 1
    n=$((n + 1))
  done
}
afirmar "Status: conan-torres tem 1 2xx e 1 3xx (o www) e nenhuma 4xx/5xx" \
  esperar_ate 30 status_conferem conan-torres "1 1 0 0"
afirmar "Status: bbcontainer tem 1 5xx e nada mais (o www do conan-torres não entra)" \
  status_conferem bbcontainer "0 0 0 1"

secao "Painel Logs: disco do Loki (Prometheus, via node exporter da borda)"

# loki_dados_bytes vem do textfile collector do node exporter da VPS (serviço
# disco-loki do traefik-default); no smoke, do túnel falso (1,5 GiB).
for titulo in "Disco do Loki" "Disco da VPS usado" "Disco do Loki medido há" "Disco do Loki ao longo do tempo"; do
  afirmar "painel '$titulo' usa a fonte prometheus" \
    test "$(jq -r --arg t "$titulo" '[.panels[]|select(.title==$t)|.targets[].datasource.uid]|unique|join(",")' "$RAIZ/grafana/dashboards/$PAINEL_LOGS")" = prometheus
  tem_dados "Logs: $titulo" "$(painel_expr "$PAINEL_LOGS" "$titulo")"
done
afirmar "Disco da VPS usado marca vermelho em 90% (onde o Loki passa a recusar linhas)" \
  test "$(jq -r '[.panels[]|select(.title=="Disco da VPS usado")|.fieldConfig.defaults.thresholds.steps[]|select(.color=="red")|.value]|first' "$RAIZ/grafana/dashboards/$PAINEL_LOGS")" = 0.9
