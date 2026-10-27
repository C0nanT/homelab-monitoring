# shellcheck shell=bash
# Carregado pelo testes/smoke.sh; usa as funções de testes/lib.sh, de
# 04-grafana.sh (grafana_api, fonte_saudavel) e de 06-loki.sh (loki_pronto).
# Fica por último (98) de propósito: derruba o Loki falso por um instante e o
# religa; verificações que dependem das linhas injetadas por 06-loki.sh devem
# vir ANTES deste arquivo (números < 98).
#
# Loki fora (túnel com a VPS caída, Loki parado): o resto da pilha segue de
# pé. Prometheus e Grafana não dependem dele; só a fonte de dados Loki falha.

secao "Loki fora: o resto da pilha continua de pé"

pilha stop loki-falso >/dev/null 2>&1

afirmar "Grafana segue saudável com o Loki fora" grafana_saudavel
afirmar "Grafana segue aceitando login com o Loki fora" grafana_api /api/org
afirmar "Prometheus segue pronto com o Loki fora" \
  curl -sf --max-time 5 "$PROM_URL/-/ready"
afirmar "alvos traefik e node seguem 'up' com o Loki fora" \
  test "$(prom_valor 'min(up{job=~"traefik|node"})')" = 1
afirmar "a fonte Prometheus segue respondendo ao Grafana com o Loki fora" \
  fonte_saudavel prometheus
fonte_falha() { ! fonte_saudavel "$1"; }
afirmar "só a fonte Loki falha (teste da fonte não dá OK)" fonte_falha loki

# Deixa o Loki de volta, como encontrou.
pilha start loki-falso >/dev/null 2>&1
if esperar_ate 90 loki_pronto; then
  ok "Loki falso volta a responder depois de religado"
else
  falha "Loki falso volta a responder em 90s"
fi
