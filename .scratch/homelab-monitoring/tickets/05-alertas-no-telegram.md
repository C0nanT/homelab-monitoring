# 05: Alertas no Telegram

> **Difficulty:** Standard: **suggested model:** Sonnet (Claude Code) / Sonnet (Cursor). Suggestion only, use whatever model you have to hand.

**Spec:** ../SPEC.md

**What to build:** O Grafana avisa no Telegram (e avisa de novo quando resolve) quando: um certificado tem menos de 20 dias (pelo Traefik ou pelo blackbox); um site fica fora por 5 minutos; a taxa de 5xx de um serviço passa de 5% por 10 minutos com tráfego mínimo; o disco da VPS passa de 85%; o job `traefik` ou `node` fica `down` por 5 minutos. Regras, contact point e política de notificação provisionados por arquivo; token e chat ID só no `.env`.

**Seams:**
- Smoke test local do `homelab-monitoring` (regras provisionadas; regra de certificado dispara com a série falsa)

**Blocked by:** 04 (Grafana provisionado)

Status: ready-for-human

- [x] Alertas pelo Grafana, sem Alertmanager
- [x] Contact point Telegram e política de notificação provisionados; envio de resolução ligado
- [x] As cinco regras com os limites da spec, ajustáveis num lugar só
- [x] Regra de 5xx não dispara com tráfego quase zero
- [x] Mensagem diz qual site/serviço/certificado e o valor atual
- [x] Smoke: regras existem pela API do Grafana; a de certificado entra em disparo com a série falsa do ticket 03 (sem enviar Telegram de verdade)
- [x] README: criar o bot no BotFather, achar o chat ID, preencher o `.env`, mandar um alerta de teste
