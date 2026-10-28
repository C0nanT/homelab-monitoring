# implement-spec: worktrees sempre na base certa

Status: ready-for-agent

## Problem Statement

Na sessão `grafana-api` (2026-10-28), 3 dos 4 implementadores começaram num worktree em `6c021af` (o `main`), não na branch de integração, e cada um teve de resetar. A skill pede para conferir a base, mas o passo depende de cada agente lembrar.

Os tickets e a spec ficam em `.scratch/`, que não é rastreado. Eles não existem dentro dos worktrees, e os implementadores só os leram porque o prompt trazia o caminho absoluto.

## Solution

O prompt de cada implementador abre com a branch de integração e o sha esperado, e o primeiro passo é conferir e resetar se for diferente. Se o harness aceitar escolher a base do worktree, a skill usa isso. A skill também diz que os tickets e a spec são lidos pelo caminho absoluto no checkout principal.

## User Stories

1. Como dono, quero que implementadores nunca trabalhem sobre uma base velha.
2. Como agente, quero o sha esperado no prompt, para conferir sem procurar.
3. Como agente, quero saber que a spec e os tickets estão fora do worktree, por caminho absoluto.

## Implementation Decisions

- Passo 4 da skill: o prompt do implementador traz branch e sha na primeira linha. A conferência de base já descrita fica como está.
- Uma frase no passo 4 sobre ler spec e tickets do checkout principal por caminho absoluto.
- Investigar, no começo, se a ferramenta de agentes aceita uma base para o worktree. Em caso positivo, preferir isso ao reset manual.
- Depois de editar o `SKILL.md`, atualizar `RESUMO.md` e `TRADUCAO.pt-BR.md` pela skill `traduzir`.

## Testing Decisions

- **Seam:** nenhum teste automatizado. Verificação: reler o passo 4.
- Confirmação real na próxima execução: nenhum implementador precisa resetar a base.

## Out of Scope

- Rastrear `.scratch/` no git.
- Os passos de espera e de merge (specs `05-implement-spec-sem-wakeup` e `06-implement-spec-merge-inline`).

## Further Notes

- Origem: retro da sessão `grafana-api` (2026-10-28), item 4.
- Fica em `~/.claude/skills/implement-spec/`. Roda por último das três specs que editam o mesmo arquivo.
