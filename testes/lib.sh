# shellcheck shell=bash
# Funções auxiliares do smoke test. Este arquivo é carregado (source) pelo
# testes/smoke.sh e também fica disponível para os arquivos em
# testes/verificacoes/. Não execute diretamente.
#
# Variáveis esperadas (definidas pelo smoke.sh):
#   PROM_URL   endereço do Prometheus no loopback (ex.: http://127.0.0.1:9090)

FALHAS=0
SUCESSOS=0

ok() {
  SUCESSOS=$((SUCESSOS + 1))
  printf '  \033[32mOK\033[0m    %s\n' "$1"
}

falha() {
  FALHAS=$((FALHAS + 1))
  printf '  \033[31mFALHA\033[0m %s\n' "$1"
  if [ -n "${2:-}" ]; then
    printf '        %s\n' "$2"
  fi
}

secao() {
  printf '\n== %s ==\n' "$1"
}

# afirmar DESCRICAO COMANDO...  -> OK se o comando terminar com sucesso.
afirmar() {
  local desc="$1"
  shift
  if "$@" >/dev/null 2>&1; then
    ok "$desc"
  else
    falha "$desc" "comando falhou: $*"
    return 1
  fi
}

# esperar_ate SEGUNDOS COMANDO...  -> repete o comando até dar certo ou estourar o tempo.
esperar_ate() {
  local limite="$1"
  shift
  local fim=$((SECONDS + limite))
  until "$@" >/dev/null 2>&1; do
    [ "$SECONDS" -ge "$fim" ] && return 1
    sleep 1
  done
}

# prom_consulta EXPRESSAO -> imprime o JSON da consulta instantânea na API do Prometheus.
prom_consulta() {
  curl -sf --max-time 5 -G "$PROM_URL/api/v1/query" --data-urlencode "query=$1"
}

# prom_valor EXPRESSAO -> imprime o valor da 1ª série da consulta (vazio se não houver).
prom_valor() {
  prom_consulta "$1" | jq -r '.data.result[0].value[1] // empty'
}

# probe_valor ALVO -> imprime probe_success do alvo (rótulo instance), vazio se ainda não coletou.
probe_valor() {
  prom_valor "probe_success{job=\"sites\",instance=\"$1\"}"
}

# afirmar_probe DESCRICAO ALVO VALOR_ESPERADO (0 ou 1)
afirmar_probe() {
  local desc="$1" alvo="$2" esperado="$3" valor
  valor="$(probe_valor "$alvo")"
  if [ "$valor" = "$esperado" ]; then
    ok "$desc"
  else
    falha "$desc" "probe_success de $alvo esperado: $esperado; recebido: '${valor:-nenhum}'"
    return 1
  fi
}
