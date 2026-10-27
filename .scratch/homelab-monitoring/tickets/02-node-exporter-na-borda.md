# 02: Node exporter na pilha de borda (`traefik-default`)

> **Difficulty:** Heavy: **suggested model:** Opus (Claude Code) / Opus or the strongest reasoning model available (Cursor). Suggestion only, use whatever model you have to hand.

**Spec:** ../SPEC.md

**What to build:** No repositório `traefik-default`, o `docker-compose.yml` da borda ganha um node exporter que expõe CPU, memória, disco e rede do host em `127.0.0.1:9100`, e só aí: nada na interface pública, nada na rede `proxy`. O smoke da borda confere isso.

**Seams:**
- Extensão do smoke do `traefik-default` (node exporter só no loopback)

**Blocked by:** None (can start immediately)

Status: ready-for-human

- [x] Serviço com tag fixa, `network_mode: host`, `pid: host`, raiz do host montada só para leitura, escutando em `127.0.0.1:9100`
- [x] Fora da rede `proxy`
- [x] Nova verificação em `testes/verificacoes/`: responde em `127.0.0.1:9100` com métricas `node_`; não responde no IP não-loopback da máquina; não responde de um container vizinho na rede `proxy`
- [x] `testes/smoke.sh` e `testes/docs.sh` passam
- [x] README do `traefik-default` cita a porta 9100 junto com 8080/8082 (loopback, acesso por túnel) e o roteiro de versão cobre a nova imagem
- [x] Ainda não aplicado na VPS (fica no ticket 06)
