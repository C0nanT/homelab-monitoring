# 01: Smoke em portas próprias, com checagem de porta livre

> **Difficulty:** Standard: **suggested model:** Sonnet (Claude Code) / Sonnet (Cursor). Suggestion only, use whatever model you have to hand.

**Spec:** ../SPEC.md

**What to build:** o smoke roda com a pilha real de pé, sem parar nem mexer em nada dela. Por padrão usa 19090 (Prometheus) e 13000 (Grafana) no `127.0.0.1`; `PORTA_PROMETHEUS` e `PORTA_GRAFANA` continuam valendo. Antes de qualquer `docker compose up`, confere se as duas portas estão livres no `127.0.0.1`; se alguma estiver ocupada, sai com mensagem que diz qual porta e qual variável trocar. O aviso do topo do script (hoje só proíbe) e o README (seção do smoke e os passos "pare a pilha real" / "usa 127.0.0.1:9090" do fluxo de atualização de imagens) passam a dizer que o smoke convive com a pilha real, quais portas usa e como trocá-las.

Atenção: o `testes/smoke.env` também fixa a porta do Prometheus (9090) e o padrão do script é lido por ele; os dois precisam concordar com 19090, senão o padrão novo não vale.

**Seams:**
- O próprio smoke: rodar com a pilha real de pé dá 0 falha; contêineres e regras de alerta da pilha real iguais antes e depois.
- `docs.sh`: README cita as portas do smoke; aviso do topo não manda mais parar a pilha real.

**Blocked by:** None (can start immediately)

Status: ready-for-human

- [x] Padrão do smoke é 19090/13000; variáveis de ambiente ainda trocam as portas (inclui o valor em `smoke.env`)
- [x] Checagem de porta livre roda antes do primeiro `docker compose up` e olha só o `127.0.0.1`
- [x] Com a 13000 ocupada (servidor de teste), o smoke sai antes de subir contêineres, com a porta e a variável na mensagem (teste manual)
- [x] Smoke com a pilha real de pé: 0 falha, mesmos contêineres e mesmas regras de alerta da pilha real antes e depois
- [x] Aviso do topo de `smoke.sh` reescrito em forma positiva; README atualizado nos três pontos que citam 9090/3000 ou mandam parar a pilha
- [x] Verificação nova em `docs.sh` (padrão ok/FALHA): README cita as portas do smoke e o aviso não manda parar a pilha real; `docs.sh` passa
