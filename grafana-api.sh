#!/usr/bin/env bash
# Chama a API do Grafana e imprime o JSON da resposta (pronto para o jq).
#
# Uso:   ./grafana-api.sh MÉTODO CAMINHO [CORPO_JSON]
#        echo '{...}' | ./grafana-api.sh POST CAMINHO
# Ex.:   ./grafana-api.sh GET /api/v1/provisioning/alert-rules | jq length
#
# Sem variáveis, fala com a pilha real: lê GRAFANA_SENHA_ADMIN e PORTA_GRAFANA
# do .env desta pasta (porta padrão 3000, no loopback). Para falar com outra
# pilha (é o que o smoke faz), defina no ambiente:
#   GRAFANA_URL            endereço (ex.: http://127.0.0.1:3000)
#   GRAFANA_SENHA_ADMIN    senha do usuário admin
# Resposta não 2xx: sai com 1 mostrando o código HTTP e o corpo no stderr.
# A senha nunca vai na linha de comando do curl nem em nenhuma saída.

set -uo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ "$#" -lt 2 ] || [ "$#" -gt 3 ]; then
  echo "uso: $0 MÉTODO CAMINHO [CORPO_JSON]" >&2
  exit 2
fi
metodo="$1"
caminho="$2"

# valor_env VARIÁVEL -> valor da variável no .env (sem executar o arquivo).
valor_env() {
  [ -f "$RAIZ/.env" ] || return 0
  grep -E "^$1=" "$RAIZ/.env" | tail -n 1 | cut -d= -f2- | sed -E "s/^(['\"])(.*)\1\$/\2/"
}

senha="${GRAFANA_SENHA_ADMIN:-$(valor_env GRAFANA_SENHA_ADMIN)}"
if [ -z "$senha" ]; then
  echo "grafana-api: GRAFANA_SENHA_ADMIN não definida (nem no ambiente, nem no .env)" >&2
  exit 1
fi
url="${GRAFANA_URL:-http://127.0.0.1:${PORTA_GRAFANA:-$(valor_env PORTA_GRAFANA)}}"
url="${url%/}"
case "$url" in
  *:) url="${url}3000" ;; # PORTA_GRAFANA vazia -> porta padrão
esac

# Corpo: argumento, ou entrada padrão (só quando não for terminal).
corpo=""
if [ "$#" -eq 3 ]; then
  corpo="$3"
elif [ ! -t 0 ]; then
  case "$metodo" in POST | PUT | PATCH) corpo="$(cat)" ;; esac
fi

# A senha vai por arquivo de configuração do curl (temporário, modo 600,
# removido ao sair), não pela linha de comando, para não aparecer no ps.
senha_cfg="${senha//\\/\\\\}"
senha_cfg="${senha_cfg//\"/\\\"}"
cfg="$(mktemp)" || exit 1
erro_curl="$(mktemp)" || exit 1 # stderr do curl, separado do corpo (modo 600)
trap 'rm -f "$cfg" "$erro_curl"' EXIT
printf 'user = "admin:%s"\n' "$senha_cfg" >"$cfg"

args=(-sS --max-time 20 -X "$metodo" -K "$cfg"
  -H 'Accept: application/json' -o - -w '\n%{http_code}')
if [ -n "$corpo" ]; then
  args+=(-H 'Content-Type: application/json' --data-binary @-)
fi

# escondida TEXTO -> TEXTO sem a senha (defesa extra).
escondida() { printf '%s' "${1//"$senha"/***}"; }

if ! resposta="$(curl "${args[@]}" "$url$caminho" <<<"$corpo" 2>"$erro_curl")"; then
  echo "grafana-api: falha ao chamar $metodo $caminho: $(escondida "$(cat "$erro_curl")")" >&2
  exit 1
fi
codigo="${resposta##*$'\n'}"
json="${resposta%$'\n'*}"

case "$codigo" in
  2??) printf '%s\n' "$(escondida "$json")" ;;
  *)
    echo "grafana-api: $metodo $caminho -> HTTP $codigo" >&2
    escondida "$json" >&2
    echo >&2
    exit 1
    ;;
esac
