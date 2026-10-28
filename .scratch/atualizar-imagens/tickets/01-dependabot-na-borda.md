# 01: Dependabot das imagens na borda (`traefik-default`)

> **Difficulty:** Standard: **suggested model:** Sonnet (Claude Code) / Sonnet (Cursor). Suggestion only, use whatever model you have to hand.

**Spec:** ../SPEC.md

**What to build:** No repositório `traefik-default`, o Dependabot passa a abrir um PR por mês com as imagens da borda que tiveram versão nova (Traefik, socket-proxy, node exporter, BusyBox, Loki, Alloy e o whoami do exemplo), só com versões publicadas há pelo menos 14 dias, sem nunca propor um BusyBox `X.Y.0` e sem trocar a variante `-musl`. O README da borda explica como revisar e aplicar esse PR na VPS e avisa que o PR do Loki chega também no `homelab-monitoring` e que os dois são aprovados juntos. O `docs.sh` acusa se a configuração sumir ou deixar de cobrir algum compose com imagem.

**Seams:**
- Seam 1 do spec: o `testes/docs.sh` do `traefik-default`

**Blocked by:** None (can start immediately)

Status: ready-for-agent

- [ ] Antes de escrever a configuração, conferido na documentação atual do Dependabot que o `cooldown` vale para o ecossistema `docker-compose` e qual é a sintaxe de `ignore.versions` para bloquear BusyBox `X.Y.0`; se a regra não for expressável, ignorar só `semver-minor` do BusyBox e documentar o salto de linha à mão
- [ ] Configuração do Dependabot com comentários em pt-BR (modelo: a do bbcontainer): ecossistema `docker-compose` cobrindo o compose principal e o do exemplo whoami, agenda mensal, um grupo só, `cooldown` de 14 dias, `open-pull-requests-limit` acima de 0
- [ ] Nenhum workflow ou regra de auto-merge
- [ ] YAML lido sem erro por um parser (Python ou `yq` via Docker)
- [ ] README: a seção de versões começa pelo PR do Dependabot (ler as notas, rodar o smoke da borda, aprovar, `git pull` + `up -d` na VPS); o roteiro à mão continua documentado
- [ ] README: nota de que o PR do Loki chega nos dois repositórios e os dois são aprovados juntos
- [ ] README: onde conferir se o Dependabot leu a configuração (*Insights → Dependency graph → Dependabot*), como passo do checklist manual depois do merge
- [ ] `testes/docs.sh` confere: a configuração existe, cobre `docker-compose` e os diretórios com compose, e o README tem o roteiro de revisão e a nota do Loki
- [ ] `testes/docs.sh` e `testes/smoke.sh` da borda passam
