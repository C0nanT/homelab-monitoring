# 03: Painel Logs no Grafana (`homelab-monitoring`)

> **Difficulty:** Standard: **suggested model:** Sonnet (Claude Code) / a mid-tier model (Cursor). Suggestion only, use whatever model you have to hand.

**Spec:** ../SPEC.md

**What to build:** Um painel **Logs** próprio, provisionado por arquivo: variável `site`, busca de texto, logs da aplicação, log de acesso do site, linhas de erro ao longo do tempo e respostas por classe de status a partir do log de acesso. Link no topo dos painéis Sites e Traefik para ele. README com a seção "Logs".

**Seams:**
- Seam 2 do spec: extensão do smoke do `homelab-monitoring` (painel)

**Blocked by:** 02

Status: ready-for-human

- [x] Painel `Logs` (uid fixo) em `grafana/dashboards/`, fonte `loki`, variável `site` (sites por padrão, borda como opção), caixa de busca
- [x] Painéis: logs da aplicação, log de acesso (status, método, caminho, `ClientHost`, duração via `| json`), série de linhas de erro, respostas por classe de status
- [x] Link para o painel Logs no topo de Sites e Traefik
- [x] Smoke: o painel existe e as consultas dele, executadas pela API do Grafana com as linhas injetadas do ticket 02, devolvem dados filtrados pelo site escolhido
- [x] `testes/smoke.sh` e `testes/docs.sh` passam
- [x] README: seção "Logs" (painel, Explore, exemplos de LogQL), tabela de painéis atualizada
