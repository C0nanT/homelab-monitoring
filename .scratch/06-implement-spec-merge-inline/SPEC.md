# implement-spec faz merge limpo sem subagente

Status: ready-for-agent

## Problem Statement

O passo 5 de `implement-spec` manda um merger subagent juntar cada implementador. Na sessão `grafana-api` (2026-10-28) foram 4 spawns, cerca de 10 s e 33 mil tokens cada, para merges sem conflito. O trabalho era um `git merge --no-ff` com mensagem fixa.

## Solution

O orquestrador faz o merge direto. O merger subagent só entra quando o merge dá conflito.

## User Stories

1. Como dono, quero que merges limpos custem poucos tokens.
2. Como agente, quero saber quando devo chamar o merger: só em conflito.
3. Como dono, quero que a mensagem do merge e a atribuição continuem iguais.

## Implementation Decisions

- Passo 5: o orquestrador roda o merge na branch de integração. Se o git relatar conflito, aborta o merge e delega a um merger subagent (Sonnet, medium, como hoje).
- A skill mantém a seção "Models and effort" coerente: o merger continua listado, agora como exceção.
- Depois de editar o `SKILL.md`, atualizar `RESUMO.md` e `TRADUCAO.pt-BR.md` pela skill `traduzir`.

## Testing Decisions

- **Seam:** nenhum teste automatizado. Verificação: reler o passo 5 e a seção de modelos.
- Confirmação real na próxima execução: merges limpos sem spawn de merger, e um conflito provocado de propósito chega ao merger.

## Out of Scope

- Remover o merger subagent.
- O passo de worktree (spec `07-implement-spec-base-do-worktree`).

## Further Notes

- Origem: retro da sessão `grafana-api` (2026-10-28), item 3.
- Fica em `~/.claude/skills/implement-spec/`. Roda depois de `05-implement-spec-sem-wakeup` (mesmo arquivo).
