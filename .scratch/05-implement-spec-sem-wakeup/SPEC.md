# implement-spec espera subagentes sem agendar wakeup

Status: ready-for-agent

## Problem Statement

Na sessão `grafana-api` (2026-10-28) o orquestrador agendou um `ScheduleWakeup` de 20 min enquanto esperava um subagente em segundo plano. O subagente terminou antes. O wakeup voltou duas vezes como texto parecido com uma mensagem do dono, e gastou turnos explicando que não havia nada pendente.

O `ScheduleWakeup` é do modo `/loop`. A skill `implement-spec` não diz como esperar subagentes.

## Solution

A skill `implement-spec` diz que subagentes em segundo plano avisam sozinhos ao terminar, e que o orquestrador encerra o turno e espera esse aviso. Não agenda wakeup nem cron.

## User Stories

1. Como dono, quero que o orquestrador espere subagentes sem criar lembretes que voltam depois.
2. Como agente, quero uma frase clara sobre como esperar, para eu não improvisar.

## Implementation Decisions

- Uma frase positiva na seção de passos, junto do passo 4 (onde os subagentes saem em segundo plano). Sem repetir em outro lugar.
- Depois de editar o `SKILL.md`, atualizar `RESUMO.md` e `TRADUCAO.pt-BR.md` da mesma pasta pela skill `traduzir`.

## Testing Decisions

- **Seam:** nenhum teste automatizado. Verificação: reler o trecho editado e conferir que a frase existe uma vez só.
- Confirmação real na próxima execução de `implement-spec`: nenhum `ScheduleWakeup` aparece.

## Out of Scope

- Mudar o comportamento do `/loop`.
- Outras mudanças na skill (specs `06-implement-spec-merge-inline` e `07-implement-spec-base-do-worktree`).

## Further Notes

- Origem: retro da sessão `grafana-api` (2026-10-28), item 6.
- Fica em `~/.claude/skills/implement-spec/`, fora do repositório do homelab.
- É a primeira das três specs que editam o mesmo `SKILL.md`: rodar em ordem, não em paralelo.
