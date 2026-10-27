#!/bin/sh
# Ponto de entrada do container "tunel": abre e mantém o túnel SSH até a VPS.
#
# Encaminha, na rede interna da pilha (tunel:8082, tunel:9100 e tunel:3100), as
# portas que a VPS publica só no loopback dela:
#   127.0.0.1:8082  métricas do Traefik
#   127.0.0.1:9100  node exporter
#   127.0.0.1:3100  Loki (logs; o Grafana consulta por aqui)
# O usuário da VPS (metricas) só pode abrir esses três encaminhamentos: veja
# "Monitoramento a partir de outra máquina" no README do traefik-default.
#
# Variáveis (do .env, via docker-compose.yml):
#   TUNEL_HOST       IP ou nome da VPS (obrigatória)
#   TUNEL_USUARIO    usuário SSH na VPS (padrão: metricas)
#   TUNEL_PORTA_SSH  porta do sshd da VPS (padrão: 22)
# Arquivos (pasta chaves/ do repositório, montada só leitura em /chaves):
#   /chaves/id_tunel     chave privada dedicada
#   /chaves/known_hosts  chave pública do servidor (conferida sempre)
set -eu

erro() {
  echo "tunel: $*" >&2
  exit 1
}

[ -n "${TUNEL_HOST:-}" ] || erro "TUNEL_HOST vazio. Preencha o .env (veja o .env.example)."
USUARIO="${TUNEL_USUARIO:-metricas}"
PORTA="${TUNEL_PORTA_SSH:-22}"
[ -r /chaves/id_tunel ] || erro "falta chaves/id_tunel (chave privada). Veja \"Túnel até a VPS\" no README."
[ -s /chaves/known_hosts ] || erro "falta chaves/known_hosts (chave da VPS). Veja \"Túnel até a VPS\" no README."

# O ssh recusa chave privada legível por outros. A montagem é só leitura, então
# usamos uma cópia com permissão 600 dentro do container (some no restart).
cp /chaves/id_tunel /tmp/id_tunel
chmod 600 /tmp/id_tunel

# Sem a porta de monitoramento do autossh (-M 0): quem detecta o túnel morto é
# o keepalive do próprio ssh (ServerAlive*), e o autossh reabre a conexão.
# GATETIME=0: tenta de novo mesmo se a 1ª conexão falhar (PC sem rede ao ligar).
export AUTOSSH_GATETIME=0

echo "tunel: conectando em $USUARIO@$TUNEL_HOST:$PORTA (encaminha 8082, 9100 e 3100)"
# - ExitOnForwardFailure: se um encaminhamento falhar, o ssh sai (e o autossh
#   reconecta) em vez de ficar de pé sem métricas.
# - ServerAliveInterval/CountMax: ~45s sem resposta = conexão morta (suspensão,
#   troca de rede, VPS reiniciada).
# - StrictHostKeyChecking=yes com known_hosts fixo e UpdateHostKeys=no: só fala
#   com a VPS conhecida; chave do servidor diferente = recusa (nada de TOFU).
# - BatchMode: nunca pede senha nem confirmação (não há terminal).
# - 0.0.0.0 no lado do container: o Prometheus chega por tunel:8082/9100 pela
#   rede interna da pilha (o Grafana chega no Loki por tunel:3100). Nenhuma
#   porta é publicada no PC (sem "ports").
exec autossh -M 0 -N \
  -o ExitOnForwardFailure=yes \
  -o ServerAliveInterval=15 \
  -o ServerAliveCountMax=3 \
  -o ConnectTimeout=15 \
  -o StrictHostKeyChecking=yes \
  -o UserKnownHostsFile=/chaves/known_hosts \
  -o UpdateHostKeys=no \
  -o BatchMode=yes \
  -o IdentitiesOnly=yes \
  -i /tmp/id_tunel \
  -p "$PORTA" \
  -L 0.0.0.0:8082:127.0.0.1:8082 \
  -L 0.0.0.0:9100:127.0.0.1:9100 \
  -L 0.0.0.0:3100:127.0.0.1:3100 \
  "$USUARIO@$TUNEL_HOST"
