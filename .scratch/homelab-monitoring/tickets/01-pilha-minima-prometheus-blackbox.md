# 01: Pilha mínima: Prometheus + blackbox testando os sites, com smoke test

> **Difficulty:** Standard: **suggested model:** Sonnet (Claude Code) / Sonnet (Cursor). Suggestion only, use whatever model you have to hand.

**Spec:** ../SPEC.md

**What to build:** No PC, `docker compose up -d` sobe Prometheus e blackbox exporter. O blackbox testa por HTTPS a raiz e o `www` de `conantorres.dev` e `bbcontainermodular.com` e os endpoints de health, e o Prometheus guarda o resultado (`probe_success`, latência, status, `probe_ssl_earliest_cert_expiry`) com 90 dias de retenção. Prometheus só em `127.0.0.1:9090`. Um smoke test local sobe a pilha com alvos falsos (site HTTPS local no ar e um endereço que não responde), confere o resultado e derruba tudo. É a base do repositório: compose, `.gitignore`, `.env.example`, README inicial com arquitetura e roteiro de versões.

**Seams:**
- Smoke test local do `homelab-monitoring` (alvos do blackbox, Prometheus só no loopback)

**Blocked by:** None (can start immediately)

Status: ready-for-human

- [x] Imagens com tag de versão fixa; README com roteiro de atualização no estilo do `traefik-default`
- [x] Serviços com `restart: unless-stopped`; dados do Prometheus em volume nomeado; retenção de 90 dias
- [x] Módulo do blackbox exige HTTPS válido, segue redirecionamentos, usa IPv4, aceita 2xx
- [x] Lista de alvos num único lugar, separada do resto da config; adicionar site = adicionar uma linha
- [x] Job `sites` usa `/probe` com relabel `target`→`instance`
- [x] Smoke: alvo no ar dá `probe_success` 1, alvo fora dá 0 (pela API do Prometheus)
- [x] Smoke: Prometheus não responde no IP não-loopback do PC
- [x] Smoke derruba tudo no final mesmo com falha; segue o formato do `testes/smoke.sh` do `traefik-default` (contador de falhas, verificações por pasta)
- [x] `.env` e pasta de chaves no `.gitignore`; `.env.example` versionado
- [x] README explica a arquitetura (PC → túnel → loopback da VPS; blackbox → internet) e o aviso de que o uptime só vale com o PC ligado
