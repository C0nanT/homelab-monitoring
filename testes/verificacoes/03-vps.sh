# shellcheck shell=bash
# Carregado pelo testes/smoke.sh; usa as funções de testes/lib.sh.
# Coleta da VPS pelo túnel: no smoke, o serviço "tunel" é o alvo falso de
# testes/compose/03-tunel-falso.yml (mesmo nome, mesmas portas 8082 e 9100).

secao "VPS pelo túnel: jobs traefik e node"

# up{job=...} == 1 depois da 1ª coleta (até um scrape_interval: 5s no smoke).
job_up() {
  [ "$(prom_valor "up{job=\"$1\"}")" = 1 ]
}
for job in traefik node; do
  if esperar_ate 60 job_up "$job"; then
    ok "job $job está up (Prometheus coleta pelo serviço tunel)"
  else
    falha "job $job está up em 60s" \
      "up{job=\"$job\"} recebido: '$(prom_valor "up{job=\"$job\"}")'; veja Status -> Targets"
  fi
done

afirmar "job traefik coleta tunel:8082" \
  test "$(prom_consulta 'up{job="traefik"}' | jq -r '.data.result[0].metric.instance // empty')" = tunel:8082
afirmar "job node coleta tunel:9100" \
  test "$(prom_consulta 'up{job="node"}' | jq -r '.data.result[0].metric.instance // empty')" = tunel:9100

secao "VPS pelo túnel: séries usadas pelos painéis e alertas"

# Certificado vencendo em menos de 20 dias (o alerta do ticket 05 usa isto).
dias="$(prom_valor 'min((traefik_tls_certs_not_after{job="traefik"} - time()) / 86400)')"
afirmar "traefik_tls_certs_not_after tem um certificado vencendo em < 20 dias (min: ${dias:-nenhum})" \
  bash -c 'awk -v d="$1" "BEGIN { exit !(d != \"\" && d > 0 && d < 20) }"' _ "$dias"
afirmar "traefik_tls_certs_not_after também tem certificado saudável (> 20 dias)" \
  test -n "$(prom_valor 'max((traefik_tls_certs_not_after{job="traefik"} - time()) / 86400) > 20')"
afirmar "traefik_service_requests_total tem respostas 5xx" \
  test -n "$(prom_valor 'sum(traefik_service_requests_total{job="traefik",code=~"5.."})')"
afirmar "node_filesystem_size_bytes da raiz (/) existe" \
  test -n "$(prom_valor 'node_filesystem_size_bytes{job="node",mountpoint="/"}')"
afirmar "node_uname_info existe (variáveis do painel Node Exporter Full)" \
  test -n "$(prom_valor 'node_uname_info{job="node"}')"

secao "Túnel: nenhuma porta publicada no PC"

# O compose da raiz (sem os overrides do smoke): o serviço tunel não pode ter
# "ports"; só a rede interna da pilha alcança as portas encaminhadas. Assim o
# túnel manual do painel (ssh -L 8080 -L 8082) continua livre no PC.
PORTAS_TUNEL="$(docker compose --env-file "$RAIZ/testes/smoke.env" -f "$RAIZ/docker-compose.yml" \
  config --format json 2>/dev/null | jq -r '.services.tunel | if . == null then "sem serviço tunel" else (.ports // [] | length) end')"
afirmar "serviço tunel sem portas publicadas (encontradas: ${PORTAS_TUNEL:-?})" test "$PORTAS_TUNEL" = 0
