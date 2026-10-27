# 04: Colocar os logs no ar

> **Difficulty:** Light: **suggested model:** Haiku (Claude Code) / a fast model (Cursor). Suggestion only, use whatever model you have to hand.

**Spec:** ../SPEC.md

**What to build:** Subida real, manual: merge e push do `traefik-default`, `git pull` e `up -d` na VPS, `permitopen` da 3100 no `authorized_keys` do `metricas`, subida do `homelab-monitoring` atualizado e conferência com dados reais. Feito com o usuário, não por subagente.

**Blocked by:** 01, 02, 03

Status: ready-for-human

- [x] Na VPS: Loki e Alloy de pé; 3100 só no loopback; memória dentro do orçamento
- [x] `authorized_keys` do `metricas` com `permitopen="127.0.0.1:3100"`; 8080 continua recusada
- [x] No PC: túnel saudável com 3100; painel Logs com linhas reais de `conantorres.dev` e `bbcontainermodular.com` (app e acesso)
- [x] Logs continuam chegando depois de um deploy (container recriado)
- [x] HANDOFF do `traefik-default` registra o item novo
