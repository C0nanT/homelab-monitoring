# 02: Dependabot das imagens na pilha do PC (`homelab-monitoring`)

> **Difficulty:** Standard: **suggested model:** Sonnet (Claude Code) / Sonnet (Cursor). Suggestion only, use whatever model you have to hand.

**Spec:** ../SPEC.md

**What to build:** No repositório `homelab-monitoring`, o Dependabot passa a abrir um PR por mês com as imagens da pilha do PC que tiveram versão nova: Prometheus, blackbox e Grafana no compose principal, e o Alpine do Dockerfile do túnel. Só versões publicadas há pelo menos 14 dias. O README explica como revisar e aplicar o PR (parar a pilha real antes do smoke por causa das portas 9090 e 3000, `docker compose build tunel` para o Alpine, depois `pull`, `build` e `up -d`) e repete a nota de aprovar o PR do Loki junto com o da borda. O `docs.sh` acusa se a configuração sumir ou deixar de cobrir algum ecossistema. As tags do smoke ficam para o ticket 03.

**Seams:**
- Seam 1 do spec: o `testes/docs.sh` do `homelab-monitoring`

**Blocked by:** None (can start immediately)

Status: ready-for-agent

- [x] Conferido na documentação atual do Dependabot que o `cooldown` vale para os ecossistemas `docker` e `docker-compose`
- [x] Configuração do Dependabot com comentários em pt-BR: `docker-compose` no compose principal e `docker` no diretório do Dockerfile do túnel, agenda mensal, um grupo por ecossistema, `cooldown` de 14 dias, `open-pull-requests-limit` acima de 0
- [x] Nenhum workflow ou regra de auto-merge
- [x] YAML lido sem erro por um parser (Python ou `yq` via Docker)
- [x] README: a seção "Fixar e atualizar as versões" começa pelo PR do Dependabot (ler as notas, parar a pilha real, rodar o smoke, `docker compose build tunel`, aprovar, `pull` + `build` + `up -d`); o roteiro à mão continua documentado
- [ ] README: nota de que o PR do Loki chega nos dois repositórios e os dois são aprovados juntos
- [x] README: onde conferir se o Dependabot leu a configuração (*Insights → Dependency graph → Dependabot*), como passo do checklist manual depois do merge
- [x] `testes/docs.sh` confere: a configuração existe, cobre `docker-compose` e `docker` (com o diretório do túnel), e o README tem o roteiro de revisão e a nota do Loki
- [x] `testes/docs.sh` e `testes/smoke.sh` passam
