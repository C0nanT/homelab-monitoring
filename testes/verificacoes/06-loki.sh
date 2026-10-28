# shellcheck shell=bash
# Carregado pelo testes/smoke.sh; usa as funções de testes/lib.sh e de
# testes/verificacoes/04-grafana.sh (grafana_api, grafana_loki,
# fonte_saudavel).
# Loki atrás do túnel falso: o smoke injeta linhas de exemplo pela API de push
# (com os rótulos que a coleta da borda produz de verdade) e confere, pelo
# próprio Grafana, que a fonte de dados "loki" existe, responde e devolve as
# linhas certas para cada consulta.
#
# Rótulos (SPEC): projeto, servico, stream em toda linha; tipo (acesso |
# traefik) só nas linhas do Traefik; router (do RouterName) só nas de acesso.
# Linhas injetadas (marcas smoke-* identificam cada uma):
#   conan-torres/web    stdout  "GET /ofertas 200 smoke-conan-web"
#   conan-torres/web    stderr  "Error: falha ao carregar o feed smoke-conan-erro"
#   bbcontainer/app     stdout  "pedido recebido smoke-bb-app"
#   traefik/traefik     stdout  tipo=acesso router=conan-torres@docker  (JSON, 200)
#   traefik/traefik     stdout  tipo=acesso router=conan-torres-www@docker
#                               (JSON, 301 GET /contato 203.0.113.9)
#   traefik/traefik     stdout  tipo=acesso router=bbcontainer@docker   (JSON, 502)
#   traefik/traefik     stderr  tipo=traefik "smoke-traefik-acme"
#   job=atualizar-apps  stdout "<data> atualizado conan-torres" e
#                               "<data> ERRO bbcontainer: smoke-deploy-erro" (log do cron)
#   traefik/socket-proxy stderr "smoke-socket-proxy" (o ruído do socket-proxy,
#                               que o painel Logs esconde na borda)

secao "Loki falso: linhas injetadas e fonte de dados"

# O /ready só responde "ready" depois de o anel do Loki subir (~15s).
loki_pronto() {
  pilha exec -T tunel wget -qO- http://tunel:3100/ready | grep -q '^ready'
}
if esperar_ate 90 loki_pronto; then
  ok "Loki falso pronto, alcançado por tunel:3100"
else
  falha "Loki falso pronto em 90s" "veja: docker compose logs loki-falso tunel"
fi

# loki_empurrar ROTULOS_JSON LINHA -> injeta uma linha com a hora de agora.
loki_empurrar() {
  local corpo
  corpo="$(jq -nc --argjson r "$1" --arg l "$2" --arg ts "$(date +%s)000000000" \
    '{streams:[{stream:$r,values:[[$ts,$l]]}]}')"
  pilha exec -T tunel wget -qO- --header 'Content-Type: application/json' \
    --post-data "$corpo" http://tunel:3100/loki/api/v1/push
}

ACESSO_OK='{"ClientHost":"203.0.113.7","DownstreamStatus":200,"Duration":1200000,"RequestHost":"conantorres.dev","RequestMethod":"GET","RequestPath":"/ofertas","RouterName":"conan-torres@docker"}'
ACESSO_WWW='{"ClientHost":"203.0.113.9","DownstreamStatus":301,"Duration":800000,"RequestHost":"www.conantorres.dev","RequestMethod":"GET","RequestPath":"/contato","RouterName":"conan-torres-www@docker"}'
ACESSO_502='{"ClientHost":"203.0.113.8","DownstreamStatus":502,"Duration":3400000,"RequestHost":"bbcontainermodular.com","RequestMethod":"POST","RequestPath":"/pedido","RouterName":"bbcontainer@docker"}'

loki_empurrar '{"projeto":"conan-torres","servico":"web","stream":"stdout"}' 'GET /ofertas 200 smoke-conan-web'
loki_empurrar '{"projeto":"conan-torres","servico":"web","stream":"stderr"}' 'Error: falha ao carregar o feed smoke-conan-erro'
loki_empurrar '{"projeto":"bbcontainer","servico":"app","stream":"stdout"}' 'pedido recebido smoke-bb-app'
loki_empurrar '{"projeto":"traefik","servico":"traefik","stream":"stdout","tipo":"acesso","router":"conan-torres@docker"}' "$ACESSO_OK"
loki_empurrar '{"projeto":"traefik","servico":"traefik","stream":"stdout","tipo":"acesso","router":"conan-torres-www@docker"}' "$ACESSO_WWW"
loki_empurrar '{"projeto":"traefik","servico":"traefik","stream":"stdout","tipo":"acesso","router":"bbcontainer@docker"}' "$ACESSO_502"
loki_empurrar '{"projeto":"traefik","servico":"traefik","stream":"stderr","tipo":"traefik"}' 'level=error msg="smoke-traefik-acme"'
loki_empurrar '{"projeto":"traefik","servico":"socket-proxy","stream":"stderr"}' 'GET /containers/json smoke-socket-proxy'
loki_empurrar '{"job":"atualizar-apps"}' '2026-10-28 14:30:01 atualizado conan-torres'
loki_empurrar '{"job":"atualizar-apps"}' '2026-10-28 14:30:07 ERRO bbcontainer: smoke-deploy-erro'

DS_LOKI="$(grafana_api /api/datasources || echo '[]')"
afirmar "fonte de dados Loki (uid loki) existe" \
  test "$(jq -r '[.[]|select(.uid=="loki" and .type=="loki")]|length' <<<"$DS_LOKI")" = 1
afirmar "fonte de dados Loki aponta para o túnel (http://tunel:3100)" \
  test "$(jq -r '[.[]|select(.uid=="loki")|.url]|first' <<<"$DS_LOKI")" = http://tunel:3100
afirmar "fonte de dados Loki é provisionada (somente leitura na interface)" \
  test "$(jq -r '[.[]|select(.uid=="loki")|.readOnly]|first' <<<"$DS_LOKI")" = true
afirmar "Prometheus continua sendo a fonte padrão" \
  test "$(jq -r '[.[]|select(.isDefault==true)|.uid]|join(",")' <<<"$DS_LOKI")" = prometheus
afirmar "Grafana testa a fonte de dados Loki com sucesso" fonte_saudavel loki

# loki_linhas EXPRESSAO -> imprime, uma por linha, as linhas de log que o
# Grafana recebe do Loki (consulta de intervalo da última hora).
loki_linhas() {
  grafana_loki range "$1" |
    jq -r '.results.A.frames[]? | (.schema.fields|map(.name)|index("Line")) as $i | .data.values[$i][]?'
}

# afirmar_linhas DESCRICAO EXPRESSAO MARCAS_ESPERADAS MARCAS_PROIBIDAS
# (marcas separadas por espaço; "-" = nenhuma). Tenta por até 30s: o Loki leva
# um instante para servir o que acabou de receber.
LINHAS=""
tem_marcas() { # expressão marcas
  local m
  LINHAS="$(loki_linhas "$1")"
  for m in $2; do
    grep -qF -- "$m" <<<"$LINHAS" || return 1
  done
}
afirmar_linhas() {
  local desc="$1" expr="$2" esperadas="$3" proibidas="$4" m
  if ! esperar_ate 30 tem_marcas "$expr" "$esperadas"; then
    falha "$desc" "faltam marcas '$esperadas' em: $expr (recebido: ${LINHAS:-nada})"
    return 1
  fi
  if [ "$proibidas" != - ]; then
    for m in $proibidas; do
      if grep -qF -- "$m" <<<"$LINHAS"; then
        falha "$desc" "veio '$m', que não devia, em: $expr"
        return 1
      fi
    done
  fi
  ok "$desc"
}

afirmar_linhas "consulta pelo Grafana: conan-torres/web devolve só as linhas do site" \
  '{projeto="conan-torres",servico="web"}' "smoke-conan-web smoke-conan-erro" "smoke-bb-app"
afirmar_linhas "consulta pelo Grafana: bbcontainer devolve só as linhas do site" \
  '{projeto="bbcontainer"}' "smoke-bb-app" "smoke-conan-web smoke-conan-erro"
afirmar_linhas "consulta pelo Grafana: busca de texto (|= Error) acha o erro" \
  '{projeto="conan-torres"} |= "Error"' "smoke-conan-erro" "smoke-conan-web"
afirmar_linhas "consulta pelo Grafana: acesso do Traefik filtrado pelo router do site" \
  '{projeto="traefik",tipo="acesso",router="conan-torres@docker"}' '"DownstreamStatus":200' '"DownstreamStatus":502 smoke-traefik-acme'
afirmar_linhas "consulta pelo Grafana: acesso do Traefik extrai campos com | json" \
  '{tipo="acesso"} | json | DownstreamStatus >= 500' '"DownstreamStatus":502' '"DownstreamStatus":200'
afirmar_linhas "consulta pelo Grafana: log do próprio Traefik (tipo=traefik) fica separado do acesso" \
  '{projeto="traefik",tipo="traefik"}' "smoke-traefik-acme" "DownstreamStatus"
afirmar_linhas "consulta pelo Grafana: o ruído do socket-proxy chegou (controle do painel Logs)" \
  '{projeto="traefik",servico="socket-proxy"}' "smoke-socket-proxy" -
