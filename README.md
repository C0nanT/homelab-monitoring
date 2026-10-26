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
│     ▲                                 │
│  grafana ── 127.0.0.1:3000 (só o PC)  │
│     │                                 │
│     └─► tunel (autossh) ═══ SSH ═══════════════►  loopback da VPS
│         tunel:8082, tunel:9100        │            127.0.0.1:8082 Traefik
└───────────────────────────────────────┘            127.0.0.1:9100 node exporter
```

- **blackbox → internet**: testa por HTTPS a raiz e o `www` de
  `conantorres.dev` e `bbcontainermodular.com`, mais os endpoints de health.
  Guarda `probe_success`, latência, status e validade do certificado.
- **PC → túnel → loopback da VPS**: as métricas do Traefik e do node
  exporter ficam só no loopback da VPS; um túnel SSH (container `tunel`,
  usuário `metricas`) as traz para a rede interna da pilha, onde o Prometheus
  coleta os jobs `traefik` e `node`. Nenhuma porta nova é aberta na VPS nem
  publicada no PC.
- **Grafana** (`127.0.0.1:3000`): já abre com a fonte de dados Prometheus e
  três painéis (Traefik, Node Exporter Full e Sites), tudo provisionado por
  arquivo (veja "Grafana").
- O Prometheus escuta **só em `127.0.0.1:9090`** (não tem autenticação) e
  guarda **90 dias** de histórico num volume nomeado.

> **Aviso: o uptime medido aqui só vale com o PC ligado.** Se o PC dorme,
> desliga ou perde a internet, a pilha para de coletar e de avisar, e isso
> não significa que a VPS caiu. A cobertura 24/7 dos sites fica com o
> UptimeRobot (etapa final).

## Roteiro de versões

1. Pilha mínima: Prometheus + blackbox testando os sites, com smoke test.
2. node exporter na borda do `traefik-default`.
3. Túnel e coleta das métricas da VPS: jobs `traefik` e `node`.
4. **Grafana provisionado (esta versão)**: fonte de dados e painéis.
5. Alertas no Telegram (BotFather: token e chat ID no `.env`).
6. Colocar no ar: checklist manual e UptimeRobot.

## Subir a pilha

```bash
cp .env.example .env     # preencha GRAFANA_SENHA_ADMIN e TUNEL_HOST (veja "Túnel até a VPS")
docker compose up -d --build
docker compose ps
```

Grafana em <http://127.0.0.1:3000> (usuário `admin`, senha
`GRAFANA_SENHA_ADMIN` do `.env`). Prometheus em <http://127.0.0.1:9090>. Para
ver os alvos: *Status → Targets* (`sites`, `traefik` e `node`), ou a consulta
`probe_success`. Verificação rápida sem subir nada: `docker compose config -q`
(com o `.env` preenchido: sem `GRAFANA_SENHA_ADMIN` o compose recusa subir,
de propósito).

Os dados ficam no volume `prometheus-dados` e sobrevivem a
`docker compose down`. **Não use `down -v`** fora do smoke test: apaga o
histórico.

## Túnel até a VPS

O container `tunel` abre um túnel SSH (autossh) com o usuário `metricas` da
VPS e encaminha `127.0.0.1:8082` (Traefik) e `127.0.0.1:9100` (node exporter)
de lá para `tunel:8082` e `tunel:9100` na rede interna da pilha. Ele
reconecta sozinho: o keepalive do SSH (`ServerAliveInterval`) percebe a
conexão morta em menos de um minuto (suspensão do PC, troca de rede, VPS
reiniciada), o autossh reabre, e o Docker reinicia o container se ele cair
(`restart: unless-stopped`). Se um encaminhamento falhar
(`ExitOnForwardFailure`), a conexão cai e é refeita, em vez de ficar de pé
sem métricas.

O túnel não publica porta nenhuma no PC: o túnel manual do painel
(`ssh -L 8080:... -L 8082:...`, do `traefik-default`) funciona ao mesmo
tempo, sem conflito.

**Antes, na VPS:** crie o usuário `metricas` com a chave restrita, seguindo
"Monitoramento a partir de outra máquina" no README do
[`traefik-default`](../traefik-default#monitoramento-a-partir-de-outra-máquina).

**No PC**, na pasta deste repositório:

1. Gere a chave dedicada (sem senha: o container precisa usá-la sozinho; ela
   só serve para ler métricas):
   ```bash
   ssh-keygen -t ed25519 -N '' -C metricas@homelab -f chaves/id_tunel
   chmod 600 chaves/id_tunel
   ```
   A pública (`chaves/id_tunel.pub`) vai para o `authorized_keys` do
   `metricas` na VPS.
2. Pegue a chave pública **do servidor** para o `known_hosts` (o túnel recusa
   qualquer servidor que não esteja nele, `StrictHostKeyChecking=yes`):
   ```bash
   ssh-keyscan -t ed25519 IP_DA_VPS > chaves/known_hosts
   ssh-keygen -lf chaves/known_hosts
   ```
   O `ssh-keyscan` confia no que receber; confira a impressão digital
   (`SHA256:...`) com a da própria VPS, rodando lá dentro
   `ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub`. Se o `sshd` não usa a
   porta 22, use `ssh-keyscan -p PORTA ...`: a linha sai como `[IP]:PORTA`,
   que é a forma que o ssh procura.
3. Preencha o `.env`: `TUNEL_HOST=IP_DA_VPS` (e `TUNEL_USUARIO`,
   `TUNEL_PORTA_SSH`, se diferentes de `metricas` e `22`).
4. Suba e confira:
   ```bash
   docker compose up -d --build
   docker compose logs tunel     # erros de chave/known_hosts aparecem aqui
   ```
   Em *Status → Targets*, `traefik` (`tunel:8082`) e `node` (`tunel:9100`)
   devem ficar `UP`. Ou pela API:
   `curl -s 'http://127.0.0.1:9090/api/v1/query?query=up' | jq`.

`chaves/` está no `.gitignore` (menos o `.gitkeep`) e é montada só leitura
no container. Com o túnel fora, a pilha continua testando os sites; só os
jobs `traefik` e `node` ficam `down`.

## Grafana

Tudo é provisionado por arquivo e versionado: recriar o Grafana do zero
(`docker compose down` e apagar o volume `grafana-dados`) não exige um clique.

| O quê | Onde |
|---|---|
| Fonte de dados Prometheus (padrão, uid `prometheus`) | `grafana/provisioning/datasources/prometheus.yml` |
| Provedor dos painéis (relê a pasta a cada 30s) | `grafana/provisioning/dashboards/provedor.yml` |
| Painéis (JSON) | `grafana/dashboards/` |
| Alertas (etapa 5) | `grafana/provisioning/alerting/` (vazia por ora) |

- **Acesso**: só em `127.0.0.1:3000` (porta em `PORTA_GRAFANA`), usuário
  `admin` e a senha `GRAFANA_SENHA_ADMIN` do `.env`; sem ela o compose não
  sobe (não existe `admin/admin`). Cadastro de usuários e telemetria
  desligados. Para ver de outro aparelho, use túnel SSH, não abra a porta.
- **Traefik** (`traefik.json`): requisições, 5xx e latência por serviço,
  conexões, mais, no topo, a taxa de 5xx por serviço e a tabela de dias até
  vencer cada certificado (`traefik_tls_certs_not_after`).
- **Node Exporter Full** (`node-exporter-full.json`): CPU, memória, disco e
  rede da VPS, com o job `node` já selecionado.
- **Sites** (`sites.json`, próprio): no ar, status HTTP, latência total e do
  TLS por site, e os dias até vencer o certificado **lado a lado**: o que o
  blackbox recebeu de fora e o que o Traefik tem guardado.
- Os painéis são editáveis na tela só para olhar; as mudanças **não** são
  salvas (vêm dos arquivos).

### Atualizar um painel

Os painéis Traefik e Node Exporter Full vêm dos painéis públicos da
comunidade ([17346](https://grafana.com/grafana/dashboards/17346) revisão 9 e
[1860](https://grafana.com/grafana/dashboards/1860) revisão 45), salvos como
JSON no repositório (nada é baixado em tempo de execução). Ajustes feitos
sobre o original: no Traefik, a fonte de dados fixa `prometheus` no lugar de
`${DS_PROMETHEUS}`, título "Traefik" e as duas visões acrescentadas no topo;
no Node, só o job `node` pré-selecionado. Para atualizar: baixe a nova
revisão, refaça esses ajustes, troque o JSON, rode `testes/smoke.sh` (ele
confere que os painéis principais têm dados) e suba. Para criar ou ajustar um
painel: edite na tela, *Export → Save to file* e salve o JSON em
`grafana/dashboards/`.

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
redirecionamento, um 500 e um que não existe) e um túnel falso (o serviço
`tunel` vira um nginx com `/metrics` do Traefik e do node exporter, sem SSH;
inclui um certificado vencendo em 10 dias), confere pela API do
Prometheus que o alvo no ar dá `probe_success` 1 e os demais 0, que os jobs
`traefik` e `node` estão `up`, que o túnel não publica portas, que a
retenção é de 90 dias e que o Prometheus **não** responde no IP não-loopback
do PC; no Grafana, que está saudável, exige a senha, só escuta em
`127.0.0.1`, tem a fonte de dados e os três painéis e que os painéis
principais mostram dados (consultas feitas pelo próprio Grafana). Derruba tudo
no final, mesmo com falha. Usa o projeto
`homelab-smoke`, `127.0.0.1:9090` e `127.0.0.1:3000`: não rode com a pilha
real de pé. Leva
cerca de um minuto.

Para estender (as próximas etapas): uma verificação nova é um arquivo
`testes/verificacoes/NN-nome.sh`; um serviço falso novo é um override em
`testes/compose/NN-nome.yml`. Detalhes no cabeçalho do `testes/smoke.sh`.
Sem subir nada, `testes/docs.sh` confere os pontos do README.

## Fixar e atualizar as versões

As imagens estão **fixadas**, nunca `latest`: nada muda sozinho. Cada tag
aparece em um único arquivo:

- `docker-compose.yml`: `prom/prometheus:vX.Y.Z`,
  `prom/blackbox-exporter:vX.Y.Z` e `grafana/grafana:X.Y.Z`;
- `tunel/Dockerfile`: `alpine:X.Y.Z` (o autossh e o ssh vêm dos pacotes
  dessa versão do Alpine);
- `testes/smoke.env`: `nginx:X.Y.Z-alpine` (só dos sites falsos do smoke).

Para atualizar, de propósito:

1. Leia as notas de versão
   (<https://github.com/prometheus/prometheus/releases>,
   <https://github.com/prometheus/blackbox_exporter/releases>,
   <https://github.com/grafana/grafana/releases>,
   <https://alpinelinux.org/releases/>).
2. Teste antes: troque a tag no arquivo dela (só ali) e rode
   `testes/smoke.sh` (usa `127.0.0.1:9090`). O smoke não usa a imagem do
   túnel (troca-o por um alvo falso): para o Alpine, rode
   `docker compose build tunel` e confira, depois do passo 3, os jobs
   `traefik` e `node` `UP` e `docker compose logs tunel`.
3. Aplique:
   ```bash
   docker compose pull           # imagens prontas
   docker compose up -d --build  # --build reconstrói o túnel
   docker compose ps && docker compose logs --tail 50
   ```
4. Para voltar atrás, restaure a tag anterior e repita o `up -d`.

O `.env`, as chaves (`chaves/`) e o volume `prometheus-dados` ficam fora do
git e sobrevivem à troca de imagem.
