# Skill pr atualiza o corpo do PR pela API

Status: ready-for-agent

## Problem Statement

Na sessão `grafana-api` (2026-10-28), `gh pr edit --body-file` falhou com o aviso de Projects (classic) e não gravou o corpo. A falha só ficou clara quando a leitura do PR voltou vazia. O caminho que funcionou foi `gh api -X PATCH repos/<dono>/<repo>/pulls/<n> -F body=@arquivo`.

A skill `pr` só descreve o modelo do corpo e não diz como gravá-lo num PR que já existe.

## Solution

A skill `pr` passa a dizer como gravar o corpo num PR existente: pela `gh api` (PATCH), seguido de uma leitura que confirma o texto. O `gh pr edit` fica fora do caminho padrão.

## User Stories

1. Como dono, quero que atualizar o corpo de um PR funcione de primeira.
2. Como agente, quero confirmar que o corpo foi gravado, e não presumir.

## Implementation Decisions

- Uma seção curta na skill, depois do modelo do corpo: achar o PR da branch, gravar com `gh api` e ler de volta.
- Positiva, sem repetir o modelo do corpo.
- Depois de editar o `SKILL.md`, atualizar `RESUMO.md` e `TRADUCAO.pt-BR.md` pela skill `traduzir`.

## Testing Decisions

- **Seam:** nenhum teste automatizado. Verificação: num PR de teste, seguir a seção e ver o corpo gravado.

## Out of Scope

- Criar o PR.
- Mudar o modelo do corpo.

## Further Notes

- Origem: retro da sessão `grafana-api` (2026-10-28), item 5.
- Fica em `~/.claude/skills/pr/`. Independente das outras specs.
