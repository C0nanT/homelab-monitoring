# Smoke do homelab sem colidir com a pilha real

Status: ready-for-agent

## Problem Statement

O smoke do homelab sobe uma pilha de teste (projeto `homelab-smoke`) que usa as mesmas portas do host da pilha real: 9090 (Prometheus) e 3000 (Grafana). O aviso no topo do script manda não rodá-lo com a pilha real de pé.

Em 2026-10-28, para rodar o smoke, o dono (via agente) parou o Grafana e o Prometheus reais. Ao religar, o repositório estava numa branch de feature, e o Grafana real ganhou dois alertas que ainda não podiam existir. Um deles disparou no Telegram, e limpá-lo exigiu um `deleteRules` temporário.

O script já aceita outras portas (`PORTA_PROMETHEUS`, `PORTA_GRAFANA`), mas nada indica isso: o aviso só proíbe.

## Solution

O smoke passa a usar, por padrão, portas que não colidem com a pilha real: 19090 para o Prometheus e 13000 para o Grafana. Assim ele roda com a pilha real de pé, sem parar nada.

Antes de subir qualquer contêiner, o smoke confere se as portas escolhidas estão livres. Se alguma estiver ocupada, ele sai com uma mensagem que diz qual porta e como escolher outra.

O aviso do topo do script e o README passam a dizer o que fazer, e não só o que evitar.

## User Stories

1. Como dono, quero rodar o smoke com a pilha real de pé, para não ficar sem monitoramento durante o teste.
2. Como dono, quero que o smoke nunca precise parar, reiniciar nem trocar a configuração da pilha real.
3. Como dono, quero que o smoke recuse começar quando uma porta dele estiver ocupada, com a porta e a variável para trocá-la na mensagem.
4. Como dono, quero continuar podendo escolher outras portas por variável de ambiente.
5. Como agente, quero que o topo do script diga como rodar com a pilha real de pé, para eu não tirar o monitoramento do ar sem necessidade.
6. Como dono, quero que o README da seção de testes diga as portas do smoke e que ele convive com a pilha real.
7. Como dono, quero que nenhum alerta de teste chegue ao meu Telegram, como já acontece hoje com o token falso.

## Implementation Decisions

- As portas padrão do smoke mudam de 9090 e 3000 para 19090 e 13000. As variáveis `PORTA_PROMETHEUS` e `PORTA_GRAFANA` continuam valendo.
- A conferência das portas roda antes de qualquer `docker compose up`. Ela só olha a porta no `127.0.0.1` do host e reprova se houver algo escutando ali.
- Qualquer outro recurso que o smoke publique no host passa pela mesma regra: porta própria e conferência de que está livre.
- O aviso no topo do script é reescrito em forma positiva: diz que o smoke convive com a pilha real e como trocar as portas.

## Testing Decisions

- Um bom teste olha o comportamento visível: o smoke passa, a pilha real continua de pé e com a mesma configuração.
- **Seam: o próprio smoke.** Rodá-lo com a pilha real de pé deve dar 0 falha. A pilha real deve continuar com os mesmos contêineres de pé e as mesmas regras de alerta antes e depois.
- **Seam: `docs.sh`.** Confere que o README cita as portas do smoke e que o aviso do topo do script não manda mais parar a pilha real.
- Teste manual: ocupar a porta 13000 (por exemplo, com um servidor de teste) e confirmar que o smoke sai antes de subir contêineres, com a mensagem certa.
- Modelo: o próprio smoke do homelab e o padrão ok/FALHA do `docs.sh`.

## Out of Scope

- Mudar as portas da pilha real.
- Rodar o smoke em CI.
- O ajudante da API do Grafana (spec `grafana-api`).

## Further Notes

- Origem: retro da sessão do deploy pelo cron (2026-10-28), candidato 1.
