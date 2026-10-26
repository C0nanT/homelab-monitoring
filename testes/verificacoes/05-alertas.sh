# shellcheck shell=bash
# Carregado pelo testes/smoke.sh; usa as funções de testes/lib.sh e
# grafana_api (definida em 04-grafana.sh).
# Alertas: regras, contact point e política provisionados; com a série falsa
# do túnel (gerar-metricas.sh), o certificado de 10 dias dispara, o 5xx do
# serviço de tráfego alto entra em disparo e o de tráfego quase zero NÃO.
# Nenhuma mensagem real sai: no smoke api.telegram.org aponta para 127.0.0.1
# (testes/compose/05-alertas.yml) e o token é falso.

secao "Alertas: regras, contact point e política provisionados"

TITULO_CERT_TRAEFIK="Certificado vencendo (Traefik)"
TITULO_CERT_BLACKBOX="Certificado vencendo (site)"
TITULO_SITE="Site fora do ar"
TITULO_5XX="Taxa de 5xx alta"
TITULO_DISCO="Disco da VPS cheio"
TITULO_JOB="Coleta da VPS parada"

# Guarda a última resposta em REGRAS_JSON (usada no resto do arquivo).
REGRAS_JSON=""
regras_provisionadas() {
  REGRAS_JSON="$(grafana_api /api/v1/provisioning/alert-rules)" &&
    jq -e 'length >= 6' <<<"$REGRAS_JSON" >/dev/null
}
if esperar_ate 60 regras_provisionadas; then
  ok "regras provisionadas aparecem na API do Grafana"
else
  falha "regras provisionadas aparecem na API do Grafana" "GET /api/v1/provisioning/alert-rules"
fi
[ -n "$REGRAS_JSON" ] || REGRAS_JSON='[]'
for titulo in "$TITULO_CERT_TRAEFIK" "$TITULO_CERT_BLACKBOX" "$TITULO_SITE" \
  "$TITULO_5XX" "$TITULO_DISCO" "$TITULO_JOB"; do
  afirmar "regra '$titulo' existe" \
    test "$(jq -r --arg t "$titulo" '[.[]|select(.title==$t)]|length' <<<"$REGRAS_JSON")" = 1
done

# Duração e limite de cada regra (vêm do que está em grafana/provisioning/alerting).
afirmar "site fora: espera 5 minutos" \
  test "$(jq -r --arg t "$TITULO_SITE" '.[]|select(.title==$t)|.for' <<<"$REGRAS_JSON")" = 5m
afirmar "5xx: espera 10 minutos" \
  test "$(jq -r --arg t "$TITULO_5XX" '.[]|select(.title==$t)|.for' <<<"$REGRAS_JSON")" = 10m
afirmar "job parado: espera 5 minutos" \
  test "$(jq -r --arg t "$TITULO_JOB" '.[]|select(.title==$t)|.for' <<<"$REGRAS_JSON")" = 5m
limite_regra() { # TITULO REFID -> limite numérico do nó threshold (veja o bloco "limites" em regras.yml)
  jq -r --arg t "$1" --arg r "$2" '.[]|select(.title==$t)|.data[]|select(.refId==$r)|.model.conditions[0].evaluator.params[0]' <<<"$REGRAS_JSON"
}
afirmar "certificado (Traefik): limite de 20 dias" test "$(limite_regra "$TITULO_CERT_TRAEFIK" C)" = 20
afirmar "certificado (site): limite de 20 dias" test "$(limite_regra "$TITULO_CERT_BLACKBOX" C)" = 20
afirmar "5xx: limite de 5%" test "$(limite_regra "$TITULO_5XX" E)" = 5
afirmar "5xx: tráfego mínimo de 0.05 req/s" test "$(limite_regra "$TITULO_5XX" F)" = 0.05
afirmar "disco: limite de 85%" test "$(limite_regra "$TITULO_DISCO" C)" = 85
afirmar "nenhuma regra ficou com variável \$LIMITE_ sem trocar" \
  bash -c '! grep -rq "LIMITE_" "$1"' _ "$RAIZ/grafana/provisioning/alerting"

CP_JSON="$(grafana_api /api/v1/provisioning/contact-points || echo '[]')"
afirmar "contact point 'telegram' do tipo telegram existe" \
  test "$(jq -r '[.[]|select(.name=="telegram" and .type=="telegram")]|length' <<<"$CP_JSON")" = 1
afirmar "aviso de resolução ligado (disableResolveMessage false)" \
  test "$(jq -r '[.[]|select(.name=="telegram")|.disableResolveMessage]|first' <<<"$CP_JSON")" = false
afirmar "política padrão envia para o contact point telegram" \
  test "$(grafana_api /api/v1/provisioning/policies | jq -r '.receiver')" = telegram
afirmar "token do Telegram não aparece em claro na API" \
  bash -c '! printf "%s" "$1" | grep -q "$2"' _ "$CP_JSON" "$TELEGRAM_BOT_TOKEN"
afirmar "api.telegram.org aponta para 127.0.0.1 no Grafana do smoke (nada sai)" \
  bash -c '[ "$(docker exec "$1" getent hosts api.telegram.org | cut -d" " -f1)" = 127.0.0.1 ]' _ "$(pilha ps -q grafana)"

secao "Alertas: disparo com a série falsa do túnel"

# estado_alertas TITULO -> uma linha por instância EM ALERTA (pendente ou
# disparando; ignora as normais): "estado rótulo-de-identificação".
estado_alertas() {
  grafana_api /api/prometheus/grafana/api/v1/rules |
    jq -r --arg t "$1" '[.data.groups[].rules[]|select(.name==$t)][0].alerts // []
      | .[] | select(.state|test("^(Alerting|Pending|firing|pending)")) | "\(.state) \(.labels.cn // .labels.service // .labels.instance // .labels.job // "?")"'
}
# alerta_ativo TITULO PADRÃO -> sucesso se há uma instância (Alerting|Pending)
# cujo rótulo bata com o padrão.
alerta_ativo() {
  estado_alertas "$1" | grep -qE "^(Alerting|Pending|firing|pending) .*$2"
}
# aguardar_alerta TITULO PADRÃO -> espera (até 180s) por alerta_ativo.
aguardar_alerta() {
  esperar_ate 180 alerta_ativo "$1" "$2"
}

if aguardar_alerta "$TITULO_CERT_TRAEFIK" 'conantorres\.dev'; then
  ok "certificado de 10 dias (conantorres.dev) entra em disparo"
else
  falha "certificado de 10 dias (conantorres.dev) entra em disparo" "$(estado_alertas "$TITULO_CERT_TRAEFIK")"
fi
afirmar "certificado de 60 dias (bbcontainermodular.com) NÃO dispara" \
  bash -c '! printf "%s\n" "$1" | grep -q bbcontainermodular' _ "$(estado_alertas "$TITULO_CERT_TRAEFIK")"
afirmar "estado do certificado é 'Alerting' (for 0s), sem esperar" \
  bash -c 'printf "%s\n" "$1" | grep -qiE "^(alerting|firing) conantorres\.dev"' _ "$(estado_alertas "$TITULO_CERT_TRAEFIK")"

# Certificado visto de fora: o do site-ok do smoke vale só 2 dias (< 20), então
# dispara. O site-cert-ruim (CA desconhecida) e o site-fora (nome não resolve)
# falham no TLS/DNS e o blackbox nem emite probe_ssl_earliest_cert_expiry:
# nenhum alerta de certificado falso para eles (só "Site fora do ar").
if aguardar_alerta "$TITULO_CERT_BLACKBOX" 'site-ok'; then
  ok "certificado de 2 dias do site-ok (visto de fora) entra em disparo"
else
  falha "certificado de 2 dias do site-ok (visto de fora) entra em disparo" "$(estado_alertas "$TITULO_CERT_BLACKBOX")"
fi
afirmar "certificado (site): site-cert-ruim e site-fora NÃO disparam alerta de certificado" \
  bash -c '! printf "%s\n" "$1" | grep -qE "site-cert-ruim|site-fora"' _ "$(estado_alertas "$TITULO_CERT_BLACKBOX")"
# Certificado já vencido continua alertando: a expressão da regra, com o
# vencimento deslocado 30 dias para trás (o site-ok vira "vencido há ~28
# dias"), ainda devolve a série, com dias negativos. Um filtro "> 0" aplicado
# aos dias (e não ao timestamp bruto) descartaria essa série.
SELETOR_CERT_SITE='probe_ssl_earliest_cert_expiry{job="sites"}'
EXPR_CERT_SITE="$(jq -r --arg t "$TITULO_CERT_BLACKBOX" '.[]|select(.title==$t)|.data[]|select(.refId=="A")|.model.expr' <<<"$REGRAS_JSON")"
DIAS_VENCIDO="$(prom_valor "${EXPR_CERT_SITE//"$SELETOR_CERT_SITE"/"($SELETOR_CERT_SITE - 30 * 86400)"}")"
afirmar "certificado (site): vencido (dias negativos: ${DIAS_VENCIDO:-nenhum}) continua na consulta da regra" \
  awk -v d="$DIAS_VENCIDO" 'BEGIN{exit !(d != "" && d < 0)}'

if aguardar_alerta "$TITULO_SITE" 'site-fora'; then
  ok "site que não existe entra na contagem dos 5 minutos (pendente/disparo)"
else
  falha "site que não existe entra na contagem dos 5 minutos" "$(estado_alertas "$TITULO_SITE")"
fi

if aguardar_alerta "$TITULO_5XX" 'bbcontainermodular@docker'; then
  ok "5xx: serviço com ~10% de 5xx e tráfego alto entra na contagem dos 10 minutos"
else
  falha "5xx: serviço com ~10% de 5xx e tráfego alto entra na contagem" "$(estado_alertas "$TITULO_5XX")"
fi
# Sem a regra de tráfego mínimo, este serviço dispararia: a taxa de 5xx dele passa do limite.
TAXA_API="$(prom_valor '100 * sum(rate(traefik_service_requests_total{service="api@internal",code=~"5.."}[10m])) / sum(rate(traefik_service_requests_total{service="api@internal"}[10m]))')"
TRAFEGO_API="$(prom_valor 'sum(rate(traefik_service_requests_total{service="api@internal"}[10m]))')"
afirmar "5xx: api@internal tem taxa de 5xx acima do limite (${TAXA_API:-?}%) mas tráfego abaixo do mínimo (${TRAFEGO_API:-?} req/s)" \
  awk -v t="${TAXA_API:-0}" -v v="${TRAFEGO_API:-9}" 'BEGIN{exit !(t > 5 && v < 0.05)}'
afirmar "5xx: serviço com taxa alta e tráfego quase zero (api@internal) NÃO dispara" \
  bash -c '! printf "%s\n" "$1" | grep -q "api@internal"' _ "$(estado_alertas "$TITULO_5XX")"
afirmar "5xx: serviço sem 5xx (conantorres@docker) NÃO dispara" \
  bash -c '! printf "%s\n" "$1" | grep -q "conantorres@docker"' _ "$(estado_alertas "$TITULO_5XX")"
afirmar "disco a 60% NÃO dispara" test -z "$(estado_alertas "$TITULO_DISCO")"
afirmar "jobs traefik e node no ar NÃO disparam" test -z "$(estado_alertas "$TITULO_JOB")"
