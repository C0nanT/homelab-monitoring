# 03: Túnel com o usuário `metricas` e coleta do Traefik e do node exporter

> **Difficulty:** Heavy: **suggested model:** Opus (Claude Code) / Opus or the strongest reasoning model available (Cursor). Suggestion only, use whatever model you have to hand.

**Spec:** ../SPEC.md

**What to build:** A pilha ganha o serviço `tunel` (autossh em container) que encaminha as portas 8082 e 9100 do loopback da VPS para a rede interna da pilha, reconectando sozinho. O Prometheus coleta os jobs `traefik` e `node` por ele. No `traefik-default`, o README ganha a seção "Monitoramento a partir de outra máquina", com o usuário `metricas` sem shell e a chave restrita. No smoke, um override troca o túnel por um alvo falso que serve um `/metrics` fixo com séries do Traefik e do node exporter.

**Seams:**
- Smoke test local do `homelab-monitoring` (jobs `traefik` e `node` `up` via alvo falso)

**Blocked by:** 01 (pilha mínima), 02 (node exporter na borda)

Status: ready-for-agent

- [ ] autossh com `ExitOnForwardFailure`, keepalive e `StrictHostKeyChecking` ligado com `known_hosts` fixo
- [ ] Chave privada e `known_hosts` montados só leitura de pasta ignorada pelo git; host e usuário vêm do `.env`
- [ ] Nenhuma porta do túnel publicada no PC; túnel manual do painel (`-L 8080 -L 8082`) funciona ao mesmo tempo
- [ ] Jobs `traefik` e `node` apontam para o serviço do túnel
- [ ] Alvo falso do smoke inclui uma `traefik_tls_certs_not_after` vencendo em menos de 20 dias (usada no ticket 05)
- [ ] Smoke: `traefik` e `node` aparecem `up` pela API do Prometheus
- [ ] README do `traefik-default`: criar `metricas` sem shell/senha, `authorized_keys` com `restrict,port-forwarding,permitopen="127.0.0.1:8082",permitopen="127.0.0.1:9100"`, conferir `AllowTcpForwarding` do `sshd`, link para o `homelab-monitoring`
- [ ] README do `homelab-monitoring`: gerar a chave dedicada, pegar o `known_hosts` da VPS, preencher o `.env`
