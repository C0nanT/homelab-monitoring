# homelab-monitoring

Monitoramento da VPS (o servidor do [`traefik-default`](../traefik-default))
rodando **no meu PC**, não na VPS: Prometheus guarda as métricas, o blackbox
exporter testa os sites por fora e o Grafana mostra e avisa no Telegram. O
UptimeRobot cobre os sites 24/7, mesmo com o PC desligado.

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
> UptimeRobot (veja "UptimeRobot").

## Roteiro de versões

1. Pilha mínima: Prometheus + blackbox testando os sites, com smoke test.
2. node exporter na borda do `traefik-default`.
3. Túnel e coleta das métricas da VPS: jobs `traefik` e `node`.
4. Grafana provisionado: fonte de dados e painéis.
5. Alertas no Telegram (BotFather: token e chat ID no `.env`).
6. **Colocar no ar (esta versão)**: VPS, túnel real, checklist manual e
   UptimeRobot (veja "Colocar no ar").

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
| Alertas (contact point, política, regras) | `grafana/provisioning/alerting/` (veja "Alertas no Telegram") |

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

## Alertas no Telegram

O próprio Grafana avisa no Telegram (sem Alertmanager) e **avisa de novo quando
o problema resolve**. Tudo é provisionado por arquivo em
`grafana/provisioning/alerting/`: `contato.yml` (contact point `telegram` e
política de notificação) e `regras.yml` (as regras).

| Alerta | Dispara quando | Espera |
|---|---|---|
| Certificado vencendo (Traefik) | `traefik_tls_certs_not_after` com menos de **20 dias** | 0 |
| Certificado vencendo (site) | certificado visto de fora pelo blackbox com menos de **20 dias** | 0 |
| Site fora do ar | `probe_success` = 0 | 5 min |
| Taxa de 5xx alta | mais de **5%** das respostas de um serviço são 5xx (janela de 10 min) **e** o serviço tem mais de **0,05 req/s** | 10 min |
| Disco da VPS cheio | `/` acima de **85%** | 0 |
| Coleta da VPS parada | job `traefik` ou `node` `down` | 5 min |

Cada mensagem diz qual certificado, site ou serviço e o valor atual (ex.:
"Certificado de conantorres.dev vence em 10.0 dias"). O tráfego mínimo evita
alertar por um serviço quase parado em que 1 erro em 3 pedidos dá 33% de 5xx.

### Criar o bot e preencher o `.env`

1. No Telegram, converse com o [@BotFather](https://t.me/BotFather), envie
   `/newbot`, escolha nome e usuário e guarde o **token**
   (`123456:ABC...`).
2. Abra uma conversa com o seu bot (ou adicione-o a um grupo) e envie
   qualquer mensagem, como `/start`.
3. Descubra o **chat ID**: abra
   `https://api.telegram.org/bot<TOKEN>/getUpdates` e procure
   `"chat":{"id":...}`. Em grupo o número é negativo (ex.: `-100123...`).
4. Preencha no `.env`: `TELEGRAM_BOT_TOKEN` e `TELEGRAM_CHAT_ID` (o compose
   não sobe sem eles; o token só existe no `.env`, que não vai para o git).
5. `docker compose up -d` (ou `docker compose up -d grafana` se a pilha já
   estava de pé).

### Mandar um alerta de teste

No Grafana (`http://127.0.0.1:3000`): *Alerting → Contact points → telegram →
Test* (botão "Test"/"Send test notification"). Chegando a mensagem no
Telegram, o bot, o token e o chat ID estão certos. Se não chegar:
`docker compose logs grafana | grep -i telegram` (token errado dá `401`/`404`;
chat ID errado ou bot que nunca recebeu uma mensagem sua dá `400`).

### Ajustar os limites

Os limites (20 dias, 5%, 0,05 req/s, 85%) ficam **num lugar só**: o bloco
`limites` no topo de `grafana/provisioning/alerting/regras.yml`. Depois de
mudar, `docker compose restart grafana`. Eles não estão no `.env` porque o
Grafana 13.2.3 não troca variáveis de ambiente dentro das regras (só no
contact point); testado e explicado no cabeçalho do `regras.yml`. Os tempos de
espera (`for:`) ficam em cada regra.

## Colocar no ar

A ordem para a primeira vez (ou depois de reinstalar a VPS). Os passos são
manuais; o smoke test não substitui nenhum deles.

**0. No PC: publicar a borda.** O `/opt/traefik` da VPS é um clone do
GitHub; o node exporter e a documentação do `metricas` só chegam lá
depois do merge do `feature/homelab-monitoring` na `main` do
`traefik-default` e do `git push`. Rode antes o `testes/smoke.sh` de lá.

**1. Na VPS: node exporter na borda.** Ele vem no `docker-compose.yml` do
[`traefik-default`](../traefik-default#painel-e-métricas-via-túnel-ssh):

```bash
cd /opt/traefik && git pull
docker compose up -d
docker compose ps                                   # node-exporter de pé
curl -s http://127.0.0.1:9100/metrics | head -3     # responde no loopback
sudo ss -ltnp | grep 9100                           # só 127.0.0.1:9100, nunca 0.0.0.0
```

**2. Do PC: a porta 9100 não aparece de fora.** Tem que falhar (tempo
esgotado ou conexão recusada):

```bash
curl -m 5 http://IP_DA_VPS:9100/metrics
```

**3. Na VPS: usuário `metricas`.** Siga "Monitoramento a partir de outra
máquina" no README do
[`traefik-default`](../traefik-default#monitoramento-a-partir-de-outra-máquina)
(usuário sem shell, chave restrita às portas 8082 e 9100, conferência do
`sshd` e o teste manual da chave). A chave pública vem do passo 1 de "Túnel
até a VPS", abaixo; gere-a antes.

**4. No PC: túnel e pilha.** Siga "Túnel até a VPS" (chave, `known_hosts`,
`.env`) e "Criar o bot e preencher o `.env`" (Telegram); depois
`docker compose up -d --build`.

**5. UptimeRobot.** Veja "UptimeRobot", abaixo.

**6. Confira tudo** com o "Checklist manual".

## Checklist manual

Não é automatizado: rode depois de colocar no ar e sempre que mexer na VPS,
no túnel ou no bot.

- [ ] **Túnel real com os alvos `up`.** Em *Status → Targets*
  (<http://127.0.0.1:9090/targets>), os jobs `sites`, `traefik` e `node`
  estão `UP`; nos painéis Traefik, Node Exporter Full e Sites aparecem dados
  reais da VPS.
- [ ] **A chave do `metricas` recusa shell.** `ssh -i chaves/id_tunel -o
  IdentitiesOnly=yes metricas@IP_DA_VPS` fecha na hora (ou "This account is
  currently not available.").
- [ ] **A chave do `metricas` recusa encaminhar para outra porta.** Um túnel
  para `127.0.0.1:8080` (o painel) dá `administratively prohibited` e o
  `curl` falha, enquanto o de `127.0.0.1:8082` responde. Os comandos estão no
  passo 4 ("Teste do PC") de "Monitoramento a partir de outra máquina", no
  README do
  [`traefik-default`](../traefik-default#monitoramento-a-partir-de-outra-máquina).
- [ ] **O túnel volta sozinho depois de suspender o PC.** Suspenda o PC por
  mais de um minuto, acorde e espere 1 a 2 minutos: `traefik` e `node`
  voltam a `UP` sem mexer em nada. Se não voltarem,
  `docker compose logs tunel`.
- [ ] **A coleta volta depois de reiniciar o Traefik.** Na VPS,
  `cd /opt/traefik && docker compose restart traefik`. O alvo `traefik` pode
  cair por alguns segundos e volta a `UP` sozinho no PC (o túnel aponta para
  o loopback da VPS, que não muda com o container; nada a refazer).
- [ ] **O alerta de teste chega no Telegram.** Veja "Mandar um alerta de
  teste".
- [ ] **Monitores do UptimeRobot verdes.** Os dois monitores (veja
  "UptimeRobot") aparecem *Up* no painel do UptimeRobot.

## UptimeRobot

A pilha só vê os sites com o PC ligado. O [UptimeRobot](https://uptimerobot.com)
testa os sites de fora, 24/7, no plano gratuito, e avisa quando caem. É
configurado à mão no site (sem automação); os nomes dos menus podem mudar um
pouco.

1. Crie uma conta gratuita (*Free plan*) em <https://uptimerobot.com>.
2. Cadastre o aviso primeiro, em *Alert Contacts* (ou *Integrations*):
   - **e-mail**: o da conta já vem cadastrado; basta confirmar;
   - **Telegram** (opcional): se a integração com o Telegram estiver
     disponível no seu plano, siga o assistente dela (ele dá um link para
     abrir no Telegram e liga o bot do UptimeRobot à sua conversa). Se não
     estiver, fique com o e-mail.
3. Crie um monitor para cada domínio, com *New monitor*:
   - tipo **HTTP(s)**;
   - URL `https://conantorres.dev` (o outro: `https://bbcontainermodular.com`);
   - intervalo: o menor que o plano gratuito oferecer;
   - em *Alert contacts*, marque o contato do passo 2.
4. Confira: os dois monitores ficam verdes (*Up*) em poucos minutos. Para
   testar o aviso, crie um monitor temporário para uma URL que não existe
   (ex.: `https://conantorres.dev.invalid`), espere o aviso chegar e apague
   esse monitor.

O uptime "oficial" dos sites é o do UptimeRobot; o `probe_success` da pilha
só cobre as horas com o PC ligado.

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
principais mostram dados (consultas feitas pelo próprio Grafana); nos
alertas, que as regras existem pela API, que o contact point e a política
estão certos, que o certificado de 10 dias dispara e que a regra de 5xx
entra em contagem para o serviço de tráfego alto mas não para o de tráfego
quase zero. Nenhuma mensagem real é enviada (token falso e
`api.telegram.org` apontado para `127.0.0.1` só no smoke). Derruba tudo
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
