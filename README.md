# homelab-monitoring

Monitoramento da VPS (o servidor do [`traefik-default`](../traefik-default))
rodando **no meu PC**, não na VPS: Prometheus guarda as métricas, o blackbox
exporter testa os sites por fora e (nas próximas etapas) o Grafana mostra e
avisa no Telegram.

## Arquitetura

```
 PC (esta pilha, docker compose)                       Internet / VPS
┌───────────────────────────────────────┐
│  blackbox ──────────────────────────────────────►  sites (HTTPS público)
│     ▲                                 │
│     │ /probe                          │
│  prometheus ── 127.0.0.1:9090 (só o PC)
│     │                                 │
│     └─► tunel (autossh) ═══ SSH ═══════════════►  loopback da VPS
│         (etapa seguinte)              │            127.0.0.1:8082 Traefik
└───────────────────────────────────────┘            127.0.0.1:9100 node exporter
```

- **blackbox → internet**: testa por HTTPS a raiz e o `www` de
  `conantorres.dev` e `bbcontainermodular.com`, mais os endpoints de health.
  Guarda `probe_success`, latência, status e validade do certificado.
- **PC → túnel → loopback da VPS** (próxima etapa): as métricas do Traefik e
  do node exporter ficam só no loopback da VPS; um túnel SSH (container
  `tunel`) as traz para a pilha. Nenhuma porta nova é aberta na VPS.
- O Prometheus escuta **só em `127.0.0.1:9090`** (não tem autenticação) e
  guarda **90 dias** de histórico num volume nomeado.

> **Aviso: o uptime medido aqui só vale com o PC ligado.** Se o PC dorme,
> desliga ou perde a internet, a pilha para de coletar e de avisar, e isso
> não significa que a VPS caiu. A cobertura 24/7 dos sites fica com o
> UptimeRobot (etapa final).

## Roteiro de versões

1. **Pilha mínima (esta versão)**: Prometheus + blackbox testando os sites,
   com smoke test.
2. node exporter na borda do `traefik-default`.
3. Túnel e coleta das métricas da VPS (jobs `traefik` e `node`).
4. Grafana provisionado (fonte de dados e painéis).
5. Alertas no Telegram (BotFather: token e chat ID no `.env`).
6. Colocar no ar: checklist manual e UptimeRobot.

## Subir a pilha

```bash
cp .env.example .env     # opcional nesta etapa
docker compose up -d
docker compose ps
```

Prometheus em <http://127.0.0.1:9090>. Para ver os sites: *Status →
Targets*, ou a consulta `probe_success`. Verificação rápida sem subir nada:
`docker compose config -q`.

Os dados ficam no volume `prometheus-dados` e sobrevivem a
`docker compose down`. **Não use `down -v`** fora do smoke test: apaga o
histórico.

## Adicionar um site

Adicionar um site = adicionar uma linha em `prometheus/alvos/sites.yml`
(sempre `https://`). O Prometheus relê o arquivo sozinho em até 1 minuto, sem
reiniciar. Os critérios do teste ficam em `blackbox/blackbox.yml`: HTTPS com
certificado válido, segue redirecionamentos, IPv4, aceita qualquer 2xx.

## Smoke test

```bash
testes/smoke.sh
```

Sobe a pilha com sites falsos (um no ar, um com certificado não confiado, um
redirecionamento, um 500 e um que não existe), confere pela API do
Prometheus que o alvo no ar dá `probe_success` 1 e os demais 0, que a
retenção é de 90 dias e que o Prometheus **não** responde no IP não-loopback
do PC, e derruba tudo no final, mesmo com falha. Usa o projeto
`homelab-smoke` e `127.0.0.1:9090`: não rode com a pilha real de pé. Leva
cerca de um minuto.

Para estender (as próximas etapas): uma verificação nova é um arquivo
`testes/verificacoes/NN-nome.sh`; um serviço falso novo é um override em
`testes/compose/NN-nome.yml`. Detalhes no cabeçalho do `testes/smoke.sh`.
Sem subir nada, `testes/docs.sh` confere os pontos do README.

## Fixar e atualizar as versões

As imagens estão **fixadas**, nunca `latest`: nada muda sozinho. Cada tag
aparece em um único arquivo:

- `docker-compose.yml`: `prom/prometheus:vX.Y.Z` e
  `prom/blackbox-exporter:vX.Y.Z`;
- `testes/smoke.env`: `nginx:X.Y.Z-alpine` (só dos sites falsos do smoke).

Para atualizar, de propósito:

1. Leia as notas de versão
   (<https://github.com/prometheus/prometheus/releases>,
   <https://github.com/prometheus/blackbox_exporter/releases>).
2. Teste antes: troque a tag em `docker-compose.yml` (só ali) e rode
   `testes/smoke.sh` (usa `127.0.0.1:9090`).
3. Aplique:
   ```bash
   docker compose pull
   docker compose up -d
   docker compose ps && docker compose logs --tail 50
   ```
4. Para voltar atrás, restaure a tag anterior e repita o `up -d`.

O `.env`, as chaves (`chaves/`) e o volume `prometheus-dados` ficam fora do
git e sobrevivem à troca de imagem.
