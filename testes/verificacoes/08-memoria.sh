# shellcheck shell=bash
# Carregado pelo testes/smoke.sh; usa as funções de testes/lib.sh e a função
# pilha. Todo serviço do docker-compose.yml da raiz (não os falsos do smoke:
# sites, Loki) tem teto de memória no contêiner e nenhum foi morto por falta
# de memória (OOM) até aqui. Fica depois das verificações de dados e antes do
# 98-loki-fora.sh.

secao "Memória: teto em todo serviço da pilha"

SERVICOS_PILHA="$(docker compose --env-file "$RAIZ/testes/smoke.env" -f "$RAIZ/docker-compose.yml" config --services)"
afirmar "o compose da raiz lista os serviços da pilha" test -n "$SERVICOS_PILHA"

for servico in $SERVICOS_PILHA; do
  id="$(pilha ps -q "$servico" 2>/dev/null)"
  # HostConfig.Memory é o mem_limit em bytes; 0 = sem teto.
  teto="$(docker inspect --format '{{.HostConfig.Memory}}' "$id" 2>/dev/null)"
  afirmar "$servico: teto de memória definido (HostConfig.Memory > 0)" \
    test "${teto:-0}" -gt 0
  afirmar "$servico: não foi morto por falta de memória (OOMKilled=false)" \
    test "$(docker inspect --format '{{.State.OOMKilled}}' "$id" 2>/dev/null)" = false
done
