# shellcheck shell=bash
# Carregado pelo testes/smoke.sh; usa as funções de testes/lib.sh.
# Sites vistos pelo blackbox: no ar = 1, fora/inválido = 0 (pela API do Prometheus).

secao "Blackbox: sites"

# A 1ª coleta de cada alvo leva até um scrape_interval (5s no smoke).
todos_coletados() {
  local n
  n="$(prom_consulta 'count(probe_success{job="sites"})' | jq -r '.data.result[0].value[1] // 0')"
  [ "$n" -ge 5 ]
}
if ! esperar_ate 60 todos_coletados; then
  falha "Prometheus coletou os 5 alvos do job sites em 60s"
fi

afirmar_probe "alvo no ar (HTTPS válido) -> probe_success 1" "https://site-ok:8443" 1
afirmar_probe "redirecionamento HTTPS é seguido -> probe_success 1" "https://site-ok:8443/redireciona" 1
afirmar_probe "alvo fora do ar -> probe_success 0" "https://site-fora:8443" 0
afirmar_probe "resposta 500 não é 2xx -> probe_success 0" "https://site-ok:8443/erro" 0
afirmar_probe "certificado não confiado -> probe_success 0 (validação TLS ligada)" "https://site-cert-ruim:8443" 0

validade="$(prom_valor 'probe_ssl_earliest_cert_expiry{job="sites",instance="https://site-ok:8443"} > time()')"
afirmar "probe_ssl_earliest_cert_expiry do alvo no ar é uma data futura" test -n "$validade"
afirmar "probe_http_status_code do alvo no ar é 200" \
  test "$(prom_valor 'probe_http_status_code{job="sites",instance="https://site-ok:8443"}')" = 200
afirmar "probe_duration_seconds existe para o alvo no ar" \
  test -n "$(prom_valor 'probe_duration_seconds{job="sites",instance="https://site-ok:8443"}')"

secao "Prometheus: configuração"
FLAGS="$(curl -sf --max-time 5 "$PROM_URL/api/v1/status/flags")"
afirmar "retenção de 90 dias" test "$(printf '%s' "$FLAGS" | jq -r '.data["storage.tsdb.retention.time"]')" = 90d
