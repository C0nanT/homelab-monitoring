#!/usr/bin/env bash
# Smoke test local da pilha de monitoramento.
#
# Sobe a pilha (docker-compose.yml da raiz) com os arquivos de
# testes/compose/*.yml por cima: sites HTTPS falsos (um no ar, um com
# certificado não confiado, um que não existe) e um túnel falso (/metrics do
# Traefik e do node exporter no lugar do SSH até a VPS), verifica pela API do
# Prometheus e com curl, e derruba tudo no final, mesmo se algo falhar
# (down -v só no projeto "homelab-smoke"; seus dados reais não são tocados).
#
# Convive com a pilha real: usa 127.0.0.1:${PORTA_PROMETHEUS} (19090) e
# 127.0.0.1:${PORTA_GRAFANA} (13000) do host, longe das portas 9090 e 3000 da
# pilha real, que pode ficar de pé (não pare nada). Antes de subir, confere
# que as duas estão livres; se uma estiver ocupada, sai dizendo qual e como
# trocar (PORTA_PROMETHEUS=... PORTA_GRAFANA=... testes/smoke.sh). Os alertas
# usam token falso e api.telegram.org -> 127.0.0.1. Leva ~1 minuto.
#
# Uso:   testes/smoke.sh
# Saída: código 0 se todas as verificações passarem; diferente de zero se
#        alguma falhar ou se a pilha não subir.
#
# Como estender (tickets seguintes):
#   - nova verificação: crie testes/verificacoes/NN-nome.sh. Todos os arquivos
#     da pasta são carregados em ordem alfabética depois que a pilha está de
#     pé e usam as funções de testes/lib.sh e a função pilha (docker compose
#     do projeto do smoke).
#   - novo serviço/alvo falso (ex.: testes/compose/03-tunel-falso.yml): crie
#     testes/compose/NN-nome.yml. Todos entram como override do compose.
#   - alvos do blackbox: testes/fixtures/alvos-sites.yml.
#   - a config do Prometheus do smoke é a da raiz com scrape_interval de 5s;
#     jobs novos em prometheus/prometheus.yml já valem aqui.

set -uo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$RAIZ" || exit 1

# shellcheck source=testes/lib.sh
. "$RAIZ/testes/lib.sh"

# Portas escolhidas pelo ambiente valem mais que as do smoke.env.
porta_prometheus_ambiente="${PORTA_PROMETHEUS:-}"
porta_grafana_ambiente="${PORTA_GRAFANA:-}"

# Variáveis do teste (também lidas pelos composes via testes/smoke.env).
set -a
# shellcheck source=testes/smoke.env
. "$RAIZ/testes/smoke.env"
set +a
export PORTA_PROMETHEUS="${porta_prometheus_ambiente:-${PORTA_PROMETHEUS:-19090}}"
PROM_URL="http://127.0.0.1:$PORTA_PROMETHEUS"
export PORTA_GRAFANA="${porta_grafana_ambiente:-${PORTA_GRAFANA:-13000}}"
export GRAFANA_URL="http://127.0.0.1:$PORTA_GRAFANA" # o grafana-api.sh também lê

# Pasta temporária (certificados falsos, configs geradas). Fora do repositório.
SMOKE_TMP="$(mktemp -d)" || exit 1
export SMOKE_TMP

# O projeto próprio ("homelab-smoke") separa o smoke da pilha real, e
# --env-file evita ler o .env real da máquina.
pilha() {
  local args=(-p homelab-smoke --env-file "$RAIZ/testes/smoke.env" -f "$RAIZ/docker-compose.yml")
  local f
  for f in "$RAIZ"/testes/compose/*.yml; do
    args+=(-f "$f")
  done
  docker compose "${args[@]}" "$@"
}

limpar() {
  secao "Derrubando a pilha"
  pilha down -v --remove-orphans >/dev/null 2>&1 || true
  rm -rf "$SMOKE_TMP"
}

finalizar() {
  local rc=$?
  limpar
  if [ "$rc" -eq 0 ] && [ "$FALHAS" -gt 0 ]; then
    rc=1
  fi
  printf '\nResultado: %d ok, %d falha(s). Código de saída: %d\n' \
    "$SUCESSOS" "$FALHAS" "$rc"
  exit "$rc"
}
trap finalizar EXIT
trap 'exit 130' INT TERM

secao "Preparando arquivos do teste"

# Certificados autoassinados (cada um serve como a própria CA). O "ok" é
# confiado pelo blackbox do smoke; o "ruim" não é, de propósito.
gerar_cert() { # pasta nome
  mkdir -p "$1"
  openssl req -x509 -newkey rsa:2048 -nodes -days 2 \
    -keyout "$1/key.pem" -out "$1/cert.pem" \
    -subj "/CN=$2" -addext "subjectAltName=DNS:$2" >/dev/null 2>&1
}
gerar_cert "$SMOKE_TMP/certs-ok" site-ok || { echo "openssl falhou." >&2; exit 1; }
gerar_cert "$SMOKE_TMP/certs-ruim" site-cert-ruim || { echo "openssl falhou." >&2; exit 1; }

# Mesmas configs da raiz, com só o necessário trocado (sem duplicar o resto):
# scrape de 5s no Prometheus e a CA do site falso no módulo do blackbox.
sed 's/^\(  scrape_interval:\).*/\1 5s/' "$RAIZ/prometheus/prometheus.yml" >"$SMOKE_TMP/prometheus.yml"
sed 's|^    http:$|&\n      tls_config:\n        ca_file: /smoke/ca.pem|' "$RAIZ/blackbox/blackbox.yml" >"$SMOKE_TMP/blackbox.yml"
mkdir -p "$SMOKE_TMP/alvos"
cp "$RAIZ/testes/fixtures/alvos-sites.yml" "$SMOKE_TMP/alvos/sites.yml"
# Os containers rodam com outros usuários (ex.: nobody no Prometheus).
chmod -R a+rX "$SMOKE_TMP"

if ! grep -q 'ca_file' "$SMOKE_TMP/blackbox.yml"; then
  echo "Não consegui inserir a CA do smoke em blackbox.yml (formato mudou?)." >&2
  exit 1
fi

secao "Conferindo as portas"

# Só o loopback do host: é onde o smoke publica. Qualquer coisa escutando
# ali (a pilha real, outro smoke) faria o compose falhar ou, pior, misturar.
porta_ocupada() { # porta
  (exec 3<>"/dev/tcp/127.0.0.1/$1") 2>/dev/null
}
for par in PORTA_PROMETHEUS:Prometheus PORTA_GRAFANA:Grafana; do
  var="${par%%:*}"
  if porta_ocupada "${!var}"; then
    echo "A porta ${!var} (${par##*:}) já está ocupada em 127.0.0.1." >&2
    echo "Escolha outra: $var=<porta livre> testes/smoke.sh" >&2
    # Nada subiu: sem o down -v, que derrubaria outro smoke dono da porta.
    trap - EXIT
    rm -rf "$SMOKE_TMP"
    exit 1
  fi
done

secao "Subindo a pilha"

if ! pilha up -d --wait --wait-timeout 90; then
  echo "A pilha não ficou saudável." >&2
  pilha logs --tail 50 >&2 || true
  exit 1
fi

for arquivo in "$RAIZ"/testes/verificacoes/*.sh; do
  # shellcheck source=/dev/null
  . "$arquivo"
done
