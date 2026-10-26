# shellcheck shell=bash
# Carregado pelo testes/smoke.sh; usa as funções de testes/lib.sh.
# O Prometheus não tem autenticação: só pode responder no loopback.

secao "Prometheus só no loopback"

afirmar "Prometheus responde em 127.0.0.1" curl -sf --max-time 5 "$PROM_URL/-/healthy"

PORTAS="$(pilha port prometheus 9090 2>/dev/null)"
afirmar "porta 9090 publicada apenas em 127.0.0.1" \
  bash -c 'printf "%s\n" "$1" | grep -q "^127\.0\.0\.1:" && ! printf "%s\n" "$1" | grep -qE "^(0\.0\.0\.0|\[::\]|::):"' _ "$PORTAS"

IP_LAN="$(ip -4 route get 1.1.1.1 2>/dev/null |
  awk '{for(i=1;i<=NF;i++) if($i=="src"){print $(i+1);exit}}')"
[ -n "$IP_LAN" ] || IP_LAN="$(hostname -I 2>/dev/null | awk '{print $1}')"
if [ -z "$IP_LAN" ] || [ "${IP_LAN#127.}" != "$IP_LAN" ]; then
  echo "  AVISO sem IP não-loopback nesta máquina; verificação de rede pulada"
else
  afirmar "Prometheus NÃO responde em $IP_LAN (IP não-loopback do PC)" \
    bash -c '! curl -s --max-time 3 "http://$1:$2/-/healthy"' _ "$IP_LAN" "$PORTA_PROMETHEUS"
fi
