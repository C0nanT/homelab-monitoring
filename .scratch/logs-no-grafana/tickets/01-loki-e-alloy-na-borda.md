# 01: Loki e Alloy na pilha de borda (`traefik-default`)

> **Difficulty:** Heavy: **suggested model:** Opus (Claude Code) / Opus or the strongest reasoning model available (Cursor). Suggestion only, use whatever model you have to hand.

**Spec:** ../SPEC.md

**What to build:** No repositório `traefik-default`, a pilha de borda ganha um Loki (retenção de 30 dias, só em `127.0.0.1:3100`, fora da rede `proxy`) e um Alloy que coleta os logs de todos os containers pela API do Docker via `docker-socket-proxy` (só leitura) e manda para o Loki, com os rótulos `projeto`, `servico`, `stream`, `tipo` (acesso | traefik nas linhas do Traefik) e o router derivado do `RouterName` nas linhas de acesso. O smoke da borda confere coleta, rótulos e isolamento.

**Seams:**
- Seam 1 do spec: extensão do smoke do `traefik-default`

**Blocked by:** None (can start immediately)

Status: ready-for-human

- [x] Loki com tag fixa, monolítico, armazenamento em volume nomeado, `auth_enabled: false`, retenção de 30 dias com compactor, limites de ingestão, limite de memória, healthcheck em `/ready`, publicado só em `127.0.0.1:3100`, fora da rede `proxy`
- [x] Alloy com tag fixa, descobre containers pelo `socket-proxy` (sem montar o socket bruto), sem porta publicada fora do loopback; comentário da rede `socket` atualizado
- [x] Rótulos `projeto`, `servico`, `stream`; linhas do Traefik com `tipo=acesso` ou `tipo=traefik`; rótulo do router (de `RouterName`) só nas linhas de acesso; nada vindo de `RequestHost` vira rótulo
- [x] Nova verificação em `testes/verificacoes/`: linha marcada de um container de teste chega ao Loki com `projeto`/`servico` corretos; requisição pelo Traefik gera linha `tipo=acesso` com o router; container na rede `proxy` não alcança o Loki; 3100 não responde no IP não-loopback; o Alloy/proxy recusa escrita na API do Docker
- [x] `testes/smoke.sh` e `testes/docs.sh` passam
- [x] README: Loki e Alloy na borda, porta 3100 (loopback, túnel), retenção, `permitopen="127.0.0.1:3100"` na linha do `metricas`, consulta de emergência na VPS; roteiro de versão cobre as duas imagens; SPEC do `traefik-default` registra a exceção "primeiro armazenamento de monitoramento na VPS"
- [x] Ainda não aplicado na VPS (fica no ticket 04)
