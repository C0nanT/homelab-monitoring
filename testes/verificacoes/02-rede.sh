# shellcheck shell=bash
# Carregado pelo testes/smoke.sh; usa as funções de testes/lib.sh.
# O Prometheus não tem autenticação: na pilha real não tem porta no host; no
# smoke (override 02-prometheus-porta.yml) só responde no loopback.

secao "Prometheus só no loopback"

afirmar "Prometheus responde em 127.0.0.1" curl -sf --max-time 5 "$PROM_URL/-/healthy"

PORTAS="$(pilha port prometheus 9090 2>/dev/null)"
afirmar "porta do smoke publicada apenas em 127.0.0.1" \
  bash -c 'printf "%s\n" "$1" | grep -q "^127\.0\.0\.1:" && ! printf "%s\n" "$1" | grep -qE "^(0\.0\.0\.0|\[::\]|::):"' _ "$PORTAS"

# A pilha real não publica o Prometheus: o compose base, sozinho (sem o
# override do smoke), tem o serviço prometheus e ele não tem "ports".
afirmar "compose base não publica porta do Prometheus no host" \
  bash -c 'printf "%s\n" "$1" | jq -e ".services.prometheus != null and ((.services.prometheus.ports // []) | length == 0)"' _ "$(compose_base_json)"

IP_LAN="$(ip -4 route get 1.1.1.1 2>/dev/null |
  awk '{for(i=1;i<=NF;i++) if($i=="src"){print $(i+1);exit}}')"
[ -n "$IP_LAN" ] || IP_LAN="$(hostname -I 2>/dev/null | awk '{print $1}')"
if [ -z "$IP_LAN" ] || [ "${IP_LAN#127.}" != "$IP_LAN" ]; then
  echo "  AVISO sem IP não-loopback nesta máquina; verificação de rede pulada"
else
  afirmar "Prometheus NÃO responde em $IP_LAN (IP não-loopback do PC)" \
    bash -c '! curl -s --max-time 3 "http://$1:$2/-/healthy"' _ "$IP_LAN" "$PORTA_PROMETHEUS"
fi
