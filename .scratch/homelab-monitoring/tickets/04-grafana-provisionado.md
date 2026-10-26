# 04: Grafana provisionado com os painéis Traefik, Host e Sites

> **Difficulty:** Standard: **suggested model:** Sonnet (Claude Code) / Sonnet (Cursor). Suggestion only, use whatever model you have to hand.

**Spec:** ../SPEC.md

**What to build:** A pilha ganha o Grafana em `127.0.0.1:3000`, com senha de admin do `.env`, abrindo já com a fonte de dados Prometheus e três painéis prontos: Traefik (requisições, 5xx e latência por serviço, validade dos certificados), Host (node exporter) e Sites (blackbox: no ar, latência com TLS separado, status, validade do certificado recebido). Tudo provisionado por arquivo e versionado; recriar do zero não exige clique.

**Seams:**
- Smoke test local do `homelab-monitoring` (Grafana saudável, fonte de dados e painéis provisionados)

**Blocked by:** 03 (túnel e coleta da VPS)

Status: ready-for-agent

- [ ] Imagem com tag fixa; dados em volume nomeado; login exige a senha do `.env` (sem `admin/admin`)
- [ ] Fonte de dados Prometheus como padrão, provisionada
- [ ] Painéis Traefik e Node Exporter partem dos painéis públicos da comunidade, salvos como JSON no repositório (não importados por ID em tempo de execução), ajustados aos nomes dos jobs
- [ ] Painel Sites próprio, mostrando dias até vencer o certificado (Traefik e blackbox lado a lado)
- [ ] Smoke: Grafana saudável pela API; fonte de dados e os três painéis existem; Grafana não responde fora de `127.0.0.1`
- [ ] Painéis mostram dados com o alvo falso do smoke (sem "No data" nos principais)
