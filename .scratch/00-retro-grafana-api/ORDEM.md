# Ordem de execução: retro da sessão `grafana-api` (2026-10-28)

Duas trilhas independentes. Podem andar em paralelo, mas dentro de cada trilha a ordem importa.

## Trilha A: repositório do homelab

1. `01-smoke-sem-colisao` (já existia): portas 19090/13000 e checagem de porta livre.
2. `02-smoke-aborta-claro`: `ABORTOU` no lugar de `0 falha`, e o ambiente manda no `smoke.env`. Depois da 1, que mexe no mesmo trecho do script.
3. `03-hook-pre-commit` (já existia): hook versionado com o `docs.sh`.
4. `04-hook-pre-commit-shellcheck`: acrescenta `bash -n`, shellcheck e testes isolados ao hook. Depois da 3.

As etapas 1-2 e 3-4 são independentes entre si.

## Trilha B: skills em `~/.claude/skills`

5. `05-implement-spec-sem-wakeup`: menor, abre a sequência.
6. `06-implement-spec-merge-inline`: mesmo `SKILL.md` da 5, por isso depois dela.
7. `07-implement-spec-base-do-worktree`: mesmo `SKILL.md`, por último.
8. `08-pr-corpo-via-api`: outra skill, pode rodar a qualquer momento.

## Por que esta ordem

- 5, 6 e 7 editam o mesmo arquivo: em paralelo gerariam conflito.
- 2 e 4 dependem de specs anteriores só para não editar o mesmo trecho ao mesmo tempo.
- O item 1 da retro (guardrail) é o de maior severidade: se quiser começar pelo que mais protege, comece pela 3 e pela 4.
