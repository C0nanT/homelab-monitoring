# 06: Colocar no ar: VPS, túnel real e UptimeRobot

> **Difficulty:** Heavy: **suggested model:** Opus (Claude Code) / Opus or the strongest reasoning model available (Cursor). Suggestion only, use whatever model you have to hand.

**Spec:** ../SPEC.md

**What to build:** Tudo funcionando de verdade: node exporter rodando na VPS, usuário `metricas` criado, pilha no PC coletando pelo túnel real, Telegram recebendo alerta de teste e UptimeRobot vigiando os dois domínios 24/7. Documentação dos dois repositórios fechada.

**Seams:**
- None (checklist manual da spec; os seams automatizados já foram cobertos em 01–05)

**Blocked by:** 02 (node exporter na borda), 03 (túnel e coleta da VPS), 05 (alertas no Telegram)

Status: ready-for-agent

- [x] Na VPS: `git pull` em `/opt/traefik` e `docker compose up -d`; node exporter de pé; `curl` em `127.0.0.1:9100` responde e a porta não aparece de fora
- [x] Usuário `metricas` criado conforme o README; a chave recusa shell e recusa encaminhar para outra porta (ex.: 8080)
- [x] No PC: pilha de pé; jobs `traefik`, `node` e `sites` `up`; painéis com dados reais
- [x] Túnel volta sozinho depois de suspender o PC e de reiniciar o container do Traefik
- [ ] Alerta de teste chega no Telegram
- [x] ~~UptimeRobot com monitores HTTPS para `conantorres.dev` e `bbcontainermodular.com`, aviso configurado e verde; passo a passo no README do `homelab-monitoring`~~ (descartado em 2026-10-27: pilha 100% local)
- [x] Checklist manual escrito no README do `homelab-monitoring`
- [ ] `traefik-default`: "Próximos passos → Grafana + Prometheus" aponta para o `homelab-monitoring`; `HANDOFF.md` registra node exporter, usuário `metricas` e o item 2 de "O que falta" como feito
