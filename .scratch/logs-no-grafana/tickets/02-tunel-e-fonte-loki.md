# 02: Túnel 3100 e fonte de dados Loki (`homelab-monitoring`)

> **Difficulty:** Standard: **suggested model:** Sonnet (Claude Code) / a mid-tier model (Cursor). Suggestion only, use whatever model you have to hand.

**Spec:** ../SPEC.md

**What to build:** O container `tunel` encaminha também `127.0.0.1:3100` da VPS para `tunel:3100` (healthcheck inclui a 3100); o Grafana ganha a fonte de dados Loki provisionada (uid `loki`, `http://tunel:3100`, Prometheus continua padrão). No smoke, o túnel falso passa a servir um Loki real com linhas de exemplo injetadas pela API de push, com os rótulos do spec.

**Seams:**
- Seam 2 do spec: extensão do smoke do `homelab-monitoring` (fonte de dados)

**Blocked by:** None (can start immediately)

Status: ready-for-human

- [x] `tunel/iniciar.sh` encaminha 3100; healthcheck do serviço `tunel` confere 8082, 9100 e 3100; comentários atualizados
- [x] Fonte de dados Loki provisionada por arquivo, uid `loki`, URL `http://tunel:3100`; Prometheus segue padrão
- [x] Smoke: Loki falso atrás do túnel falso (mesma tag do Loki da borda), com linhas injetadas de `conan-torres`/`web`, `bbcontainer`/`app` e acessos do `traefik` (`tipo=acesso`, router); verificação de que a fonte `loki` existe e uma consulta pelo Grafana devolve as linhas
- [x] Com o Loki fora, o resto da pilha continua de pé (Prometheus/Grafana não dependem dele)
- [x] `testes/smoke.sh` e `testes/docs.sh` passam
- [x] README: túnel com 3100, `authorized_keys` com `permitopen="127.0.0.1:3100"`, fonte de dados Loki
