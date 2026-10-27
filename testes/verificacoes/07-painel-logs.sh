# shellcheck shell=bash
# Carregado pelo testes/smoke.sh; usa as funções de testes/lib.sh, de
# 04-grafana.sh (grafana_api) e de 06-loki.sh (loki_linhas, afirmar_linhas),
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
afirmar "todas as consultas do painel Logs usam a fonte loki" \
  test "$(jq -r '[.panels[].targets[]?|select(.datasource.uid!="loki")]|length' "$RAIZ/grafana/dashboards/$PAINEL_LOGS")" = 0

# logs_expr TITULO N SITE [BUSCA] -> consulta N (0-based) do painel, com as
# variáveis trocadas como o Grafana faz (e $__auto por 1h).
logs_expr() {
  jq -r --arg t "$1" --argjson n "$2" '[.panels[]|select(.title==$t)]|first|.targets[$n].expr' \
    "$RAIZ/grafana/dashboards/$PAINEL_LOGS" |
    sed -e "s/[$]site/$3/g" -e "s/[$]busca/${4:-}/g" -e 's/[$]__auto/1h/g'
}

# logs_total EXPRESSAO -> soma dos valores de uma consulta de métrica (1h).
logs_total() {
  local corpo
  corpo="$(jq -n --arg e "$1" '{queries:[{refId:"A",datasource:{type:"loki",uid:"loki"},expr:$e,queryType:"instant",maxLines:100}],from:"now-1h",to:"now"}')"
  curl -sf --max-time 15 -u "admin:$GRAFANA_SENHA_ADMIN" -H 'Content-Type: application/json' \
    -d "$corpo" "$GRAFANA_URL/api/ds/query" |
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
afirmar_linhas "Logs da aplicação: a borda (traefik) mostra o log do Traefik sem o log de acesso" \
  "$(logs_expr 'Logs da aplicação' 0 traefik)" "smoke-traefik-acme" "DownstreamStatus smoke-conan-web"
afirmar_linhas "Logs da aplicação: busca de texto 'Error' filtra" \
  "$(logs_expr 'Logs da aplicação' 0 conan-torres Error)" "smoke-conan-erro" "smoke-conan-web"

# Log de acesso do site.
afirmar_linhas "Log de acesso: site conan-torres mostra o 200 dele (método, caminho, ClientHost)" \
  "$(logs_expr 'Log de acesso' 0 conan-torres)" "200 GET /ofertas 203.0.113.7" "502 /pedido 203.0.113.8"
afirmar_linhas "Log de acesso: site bbcontainer mostra o 502 dele" \
  "$(logs_expr 'Log de acesso' 0 bbcontainer)" "502 POST /pedido 203.0.113.8" "/ofertas 203.0.113.7"
afirmar_linhas "Log de acesso: busca de texto por caminho filtra" \
  "$(logs_expr 'Log de acesso' 0 bbcontainer pedido)" "/pedido" "/ofertas"

# Linhas de erro ao longo do tempo: A = stderr, B = texto "error" em stdout.
afirmar "Erros: conan-torres tem 1 linha de erro (stderr)" \
  esperar_ate 30 total_igual "$(logs_expr 'Linhas de erro' 0 conan-torres)" 1
afirmar "Erros: bbcontainer tem 0 linhas de erro" \
  test "$(logs_total "$(logs_expr 'Linhas de erro' 0 bbcontainer)")" = 0

# Respostas por classe de status (A=2xx, B=3xx, C=4xx, D=5xx) a partir do acesso.
afirmar "Status: conan-torres tem 1 resposta 2xx e nenhuma 5xx" \
  bash -c '[ "$1" = 1 ] && [ "$2" = 0 ]' _ \
  "$(logs_total "$(logs_expr 'Respostas por classe de status' 0 conan-torres)")" \
  "$(logs_total "$(logs_expr 'Respostas por classe de status' 3 conan-torres)")"
afirmar "Status: bbcontainer tem 1 resposta 5xx e nenhuma 2xx" \
  bash -c '[ "$1" = 1 ] && [ "$2" = 0 ]' _ \
  "$(logs_total "$(logs_expr 'Respostas por classe de status' 3 bbcontainer)")" \
  "$(logs_total "$(logs_expr 'Respostas por classe de status' 0 bbcontainer)")"
