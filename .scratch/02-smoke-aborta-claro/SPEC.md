# Smoke que avisa quando aborta e respeita o ambiente

Status: ready-for-agent

## Problem Statement

Em 2026-10-28 o smoke do homelab não conseguiu subir o Prometheus (porta 9090 ocupada pela pilha real) e terminou com `Resultado: 0 ok, 0 falha(s). Código de saída: 1`. A linha parece sucesso. Só o código de saída e um erro do `docker compose up`, no meio de centenas de linhas de log, mostravam a verdade.

Além disso, o `smoke.env` é lido depois do ambiente e sobrescreve `PORTA_PROMETHEUS` e `PORTA_GRAFANA`. Quem exporta outra porta não é obedecido, e a única saída foi editar o arquivo versionado.

## Solution

Quando o smoke termina sem ter rodado nenhuma verificação (falha ao subir a pilha, por exemplo), ele imprime `ABORTOU`, diz em que etapa parou e mostra a última mensagem de erro do `docker compose`. O placar `0 ok, 0 falha` não aparece nesse caso.

Variáveis já definidas no ambiente têm prioridade sobre o `smoke.env`, que passa a dar só os valores padrão.

## User Stories

1. Como dono, quero que um smoke que não chegou a verificar nada diga `ABORTOU`, e não `0 falha`.
2. Como agente, quero ver a causa do aborto nas últimas linhas, sem ler o log inteiro.
3. Como dono, quero escolher as portas do smoke por variável de ambiente, sem editar arquivo versionado.
4. Como dono, quero que o smoke com verificações rodadas continue com o mesmo placar e o mesmo código de saída de hoje.

## Implementation Decisions

- O smoke guarda a etapa atual ("preparando", "subindo a pilha", "verificando") e, ao sair com erro antes de "verificando", imprime `ABORTOU` com a etapa e a última linha de erro.
- O `smoke.env` é carregado sem sobrescrever o que o ambiente já definiu.
- Vem depois da spec `01-smoke-sem-colisao`: ela muda as portas padrão e a checagem de porta livre; esta spec não repete isso.

## Testing Decisions

- **Seam: o próprio smoke.** Forçar uma falha ao subir (ocupar a porta do Prometheus) e ver `ABORTOU` e código de saída diferente de zero. Rodar com portas pelo ambiente e ver que são usadas.
- **Seam: `docs.sh`.** Confere que o README diz que o ambiente tem prioridade sobre o `smoke.env`.
- Teste manual: exportar `PORTA_PROMETHEUS=19191`, rodar o smoke e confirmar a porta no `docker ps`.

## Out of Scope

- Mudar as portas padrão ou a checagem de porta livre (spec `01-smoke-sem-colisao`).
- Rodar o smoke em CI.

## Further Notes

- Origem: retro da sessão `grafana-api` (2026-10-28), item 2.
- Depende de `01-smoke-sem-colisao` só para não editar o mesmo trecho do script ao mesmo tempo.
