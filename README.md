# homelab-monitoring

Monitoring for the VPS (the server behind
[`traefik-default`](../traefik-default)) running **on my PC**, not on the VPS:
Prometheus stores the metrics, the blackbox exporter probes the sites from the
outside, and Grafana shows them and alerts on Telegram. It is 100% local:
there is no external monitor, so with the PC off nobody is watching the sites.

> Language note: documentation, dashboards and alerts are in English.
> Identifiers keep their original Portuguese names (folders and services such
> as `tunel`, `chaves/`, `testes/`; variables such as `GRAFANA_SENHA_ADMIN`;
> metric and label names such as `deploy_falhou`, `projeto`, `tipo`).

## Architecture

```
 PC (this stack, docker compose)                       Internet / VPS
┌───────────────────────────────────────┐
│  blackbox ──────────────────────────────────────►  sites (public HTTPS)
│     ▲                                 │
│     │ /probe                          │
│  prometheus ── no host port (stack network only)
│     ▲                                 │
│  grafana ── 127.0.0.1:23000 (PC only) │
│     │                                 │
│     └─► tunel (autossh) ═══ SSH ═══════════════►  VPS loopback
│         tunel:8082, :9100, :3100      │            127.0.0.1:8082 Traefik
└───────────────────────────────────────┘            127.0.0.1:9100 node exporter
                                                       127.0.0.1:3100 Loki (logs)
```

- **blackbox → internet**: probes the root and `www` of `conantorres.dev` and
  `bbcontainermodular.com` over HTTPS, plus `compras.conantorres.dev`
  (price_trail, no `www`) and the health endpoints. It records
  `probe_success`, latency, status and certificate expiry.
- **PC → tunnel → VPS loopback**: the Traefik and node exporter metrics (and
  Loki, for logs) live only on the VPS loopback. An SSH tunnel (container
  `tunel`, user `metricas`) brings them into the stack's internal network,
  where Prometheus scrapes the `traefik` and `node` jobs and Grafana queries
  Loki. No new port is opened on the VPS or published on the PC.
- **Grafana** (`127.0.0.1:23000`): starts with the Prometheus data source and
  three dashboards (Traefik, Node Exporter Full and Sites), all provisioned
  from files (see "Grafana").
- Prometheus **publishes no host port** (it has no authentication): only the
  stack's internal network reaches it (Grafana reads `prometheus:9090`). It
  keeps **90 days** of history (capped at **2 GB**) in a named volume.

> **Warning: the uptime measured here is only valid while the PC is on.** If
> the PC sleeps, shuts down or loses internet, the stack stops collecting and
> alerting, and that does not mean the VPS is down. There is no external
> monitor: with the PC off, nobody gets an alert if a site goes down (a
> deliberate decision, 100% local stack).

## Version roadmap

1. Minimal stack: Prometheus + blackbox probing the sites, with a smoke test.
2. node exporter on the `traefik-default` edge.
3. Tunnel and collection of the VPS metrics: `traefik` and `node` jobs.
4. Provisioned Grafana: data source and dashboards.
5. Telegram alerts (BotFather: token and chat ID in `.env`).
6. **Going live (this version)**: VPS, real tunnel and manual checklist (see
   "Going live").

## Bringing the stack up

```bash
cp .env.example .env     # fill in GRAFANA_SENHA_ADMIN and TUNEL_HOST (see "Tunnel to the VPS")
docker compose up -d --build
docker compose ps
```

Grafana is at <http://127.0.0.1:23000> (user `admin`, password
`GRAFANA_SENHA_ADMIN` from `.env`). Prometheus has no host port: to see the
targets and metrics, see "Querying Prometheus" below. Quick check without
starting anything: `docker compose config -q` (with `.env` filled in: without
`GRAFANA_SENHA_ADMIN` compose refuses to start, on purpose).

Data lives in the `prometheus-dados` volume and survives
`docker compose down`. **Do not use `down -v`** outside the smoke test: it
wipes the history. History is cut at 90 days or when it exceeds 2 GB,
whichever comes first.

## Querying Prometheus

Prometheus has no host port. For debugging (targets, `up`, a metric), query it
from inside the container:

```bash
docker compose exec prometheus wget -qO- 'http://localhost:9090/api/v1/query?query=up'
```

`up` is `1` for each scraped target (jobs `sites`, `traefik` and `node`).
Alternatively, in Grafana: *Explore*, Prometheus data source, query `up` or
`probe_success`.

## Tunnel to the VPS

The `tunel` container opens an SSH tunnel (autossh) with the VPS user
`metricas` and forwards `127.0.0.1:8082` (Traefik), `127.0.0.1:9100` (node
exporter) and `127.0.0.1:3100` (Loki, the logs) from there to `tunel:8082`,
`tunel:9100` and `tunel:3100` on the stack's internal network. The container
healthcheck verifies all three ports. It reconnects by itself: the SSH
keepalive (`ServerAliveInterval`) detects a dead connection in under a minute
(PC suspend, network change, VPS reboot), autossh reopens it, and Docker
restarts the container if it dies (`restart: unless-stopped`). If a forward
fails (`ExitOnForwardFailure`), the connection drops and is redone, instead of
staying up without metrics.

The tunnel publishes no port on the PC: the manual dashboard tunnel
(`ssh -L 8080:... -L 8082:...`, from `traefik-default`) works at the same time,
with no conflict.

**First, on the VPS:** create the `metricas` user with the restricted key,
following "Monitoramento a partir de outra máquina" (monitoring from another
machine) in the
[`traefik-default`](../traefik-default#monitoramento-a-partir-de-outra-máquina)
README. The `metricas` line in `authorized_keys` must allow **all three**
ports; if you set the user up before the logs existed, add the third (and only
that one):

```
restrict,port-forwarding,permitopen="127.0.0.1:8082",permitopen="127.0.0.1:9100",permitopen="127.0.0.1:3100" ssh-ed25519 AAAA... metricas@homelab
```

Without 3100 allowed, `ExitOnForwardFailure` takes the whole tunnel down (and
the metrics with it): allow the port on the VPS **before** bringing this
version up on the PC.

**On the PC**, in this repository's folder:

1. Generate the dedicated key (no passphrase: the container must use it on its
   own; it only reads metrics):
   ```bash
   ssh-keygen -t ed25519 -N '' -C metricas@homelab -f chaves/id_tunel
   chmod 600 chaves/id_tunel
   ```
   The public key (`chaves/id_tunel.pub`) goes into the VPS `metricas`
   `authorized_keys`.
2. Get the **server's** public key into `known_hosts` (the tunnel refuses any
   server not listed there, `StrictHostKeyChecking=yes`):
   ```bash
   ssh-keyscan -t ed25519 IP_DA_VPS > chaves/known_hosts
   ssh-keygen -lf chaves/known_hosts
   ```
   `ssh-keyscan` trusts whatever it receives; check the fingerprint
   (`SHA256:...`) against the VPS's own by running, on the VPS,
   `ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub`. If `sshd` does not use
   port 22, use `ssh-keyscan -p PORT ...`: the line comes out as `[IP]:PORT`,
   which is the form ssh looks up.
3. Fill in `.env`: `TUNEL_HOST=IP_DA_VPS` (and `TUNEL_USUARIO`,
   `TUNEL_PORTA_SSH`, if different from `metricas` and `22`).
4. Bring it up and check:
   ```bash
   docker compose up -d --build
   docker compose logs tunel     # key/known_hosts errors show up here
   ```
   The `traefik` (`tunel:8082`) and `node` (`tunel:9100`) targets should be
   `UP` (see "Querying Prometheus").

`chaves/` (keys) is in `.gitignore` (except `.gitkeep`) and is mounted
read-only in the container. With the tunnel down, the stack keeps probing the
sites; only the `traefik` and `node` jobs go `down` and the Loki data source
fails its test. The same applies to Loki being stopped on the VPS: neither
Prometheus nor Grafana depend on it to start.

## Grafana

Everything is provisioned from files and versioned: recreating Grafana from
scratch (`docker compose down` and deleting the `grafana-dados` volume) needs
no clicking.

| What | Where |
|---|---|
| Prometheus data source (default, uid `prometheus`) | `grafana/provisioning/datasources/prometheus.yml` |
| Loki data source (uid `loki`, `http://tunel:3100`, via the tunnel) | `grafana/provisioning/datasources/loki.yml` |
| Dashboard provider (rereads the folder every 30s) | `grafana/provisioning/dashboards/provedor.yml` |
| Dashboards (JSON) | `grafana/dashboards/` |
| Alerts (contact point, policy, rules) | `grafana/provisioning/alerting/` (see "Telegram alerts") |

- **Access**: only on `127.0.0.1:23000` (port set by `PORTA_GRAFANA`), user
  `admin` and the `GRAFANA_SENHA_ADMIN` password from `.env`; without it
  compose does not start (there is no `admin/admin`). User sign-up and
  telemetry are disabled. To view it from another device, use an SSH tunnel;
  do not open the port.
- **Host ports**: the real stack uses the 2xxxx range and the smoke test the
  1xxxx range, far from the default ports (3000, 9090...) of other projects
  running alongside. The real stack's Prometheus uses no host port at all.
- **Traefik** (`traefik.json`): requests, 5xx and latency per service,
  connections, plus, at the top, the 5xx rate per service and the table of
  days until each certificate expires (`traefik_tls_certs_not_after`).
- **Node Exporter Full** (`node-exporter-full.json`): VPS CPU, memory, disk and
  network, with the `node` job already selected.
- **Sites** (`sites.json`, custom): up/down, HTTP status, total and TLS latency
  per site, and the days until the certificate expires **side by side**: what
  blackbox received from outside and what Traefik has stored.
- **Logs** (`logs.json`, custom): application logs and the Traefik access log
  per site, error lines, responses by status class and Loki's disk usage (see
  "Logs"). Sites and Traefik have a link to it at the top.
- Dashboards are editable on screen for exploration only; changes are **not**
  saved (they come from the files).

### Updating a dashboard

The Traefik and Node Exporter Full dashboards come from the public community
dashboards ([17346](https://grafana.com/grafana/dashboards/17346) revision 9
and [1860](https://grafana.com/grafana/dashboards/1860) revision 45), saved as
JSON in the repository (nothing is downloaded at runtime). Adjustments made on
top of the originals: in Traefik, the fixed `prometheus` data source instead of
`${DS_PROMETHEUS}`, the title "Traefik" and the two views added at the top; in
Node, only the `node` job preselected. To update: download the new revision,
redo those adjustments, replace the JSON, run `testes/smoke.sh` (it checks that
the main dashboards have data) and bring it up. To create or adjust a
dashboard: edit it on screen, *Export → Save to file* and save the JSON in
`grafana/dashboards/`.

### Querying the Grafana API

`grafana-api.sh` (in the root) calls the real Grafana API with the password
from `.env` and prints JSON ready for `jq`. Usage:
`./grafana-api.sh METHOD PATH [JSON_BODY]` (the body can also come from
standard input). A non-2xx response exits with an error, showing the HTTP code
and the body. Examples:

```
./grafana-api.sh GET /api/v1/provisioning/alert-rules | jq -r '.[].title'
./grafana-api.sh GET /api/prometheus/grafana/api/v1/rules | jq '.data.groups[].rules[] | {name, state}'
./grafana-api.sh GET /api/datasources/uid/loki/health | jq
```

Respectively: the alert rule names, the state of each alert (`inactive`,
`pending` or `firing`), and whether the Loki data source responds (it errors
out if the tunnel is down).

## Logs

The sites' logs live in the VPS's Loki (30 days, collected 24/7 even with the
PC off) and reach Grafana through the tunnel (`tunel:3100`, data source
`loki`). The **Logs** dashboard (`grafana/dashboards/logs.json`, uid
`homelab-logs`) has:

- **Site** (variable): `conan-torres`, `bbcontainer`, `price_trail` or
  `traefik` (the edge; no per-router access log and none of the socket-proxy
  noise, which logs every Alloy query). Pick the period in Grafana's time
  picker.
- **Search text** (variable): filters both log lists (e.g.
  `Error`, a path, an IP, `msg="acme`). The text is literal, quotes and `\`
  included (it goes between backticks in the query: a single backtick in the
  text breaks the search). Leave it empty to see everything.
- **Error lines**: lines per interval coming from stderr or
  with `error` in the text.
- **Responses by status class**: 2xx, 3xx,
  4xx and 5xx of the site, counted from the access log (useful to cross-check
  the 5xx alert).
- **Application logs** and **Access log** (status, method, path, `ClientHost` and duration in ms, extracted with
  `| json`).
- **Log storage** (row at the bottom, `prometheus`
  source, independent of the site): how much the 30 days of logs take on the
  VPS, the whole VPS disk (red at 90%: from there up Loki **refuses** new
  lines), how long ago it was measured (red after 15 min) and the 30-day
  growth. The number comes from the `loki_dados_bytes` series, which the
  edge's `disco-loki` service measures every 5 min and the node exporter
  publishes (textfile collector); it arrives through the 9100 tunnel, `node`
  job. If the disk gets tight, lower the retention in `loki/loki.yml` of
  traefik-default.

- **Deploy (cron)** (row at the bottom, three panels; the Site variable does
  not apply here): **Deploy per site** (`ok` or `failed` for each site in the
  VPS cron's last run, series `deploy_falhou{app}`), **Last cron run** (series
  `deploy_rodada_timestamp_seconds`) and **Deploy cron log** (lines
  `atualizado <site>` and `ERRO <site>: <message>`, written by the VPS cron, with the text search).
  The cron writes both series to the node exporter's textfile collector and
  they arrive through the 9100 tunnel, `node` job; the log reaches Loki with
  the label `job="atualizar-apps"` (in Explore:
  `{job="atualizar-apps"} |= "ERRO"`).

The access log and the status classes sum the site's router and the `www` one
(`router=~"$site(-www)?@.+"`; Loki's regex matches the whole value).

With the tunnel down, only this dashboard shows a connection error; the rest of
Grafana carries on normally. For free-form queries use *Explore* (`loki`
source). Labels: `projeto`, `servico`, `stream`; on Traefik also `tipo`
(`acesso` | `traefik`) and, on access logs, `router` (e.g.
`conan-torres@docker`, `conan-torres-www@docker`). LogQL examples:

```logql
{projeto="conan-torres"} |= "Error"
{projeto="traefik", tipo="acesso", router="bbcontainer@docker"} | json | DownstreamStatus >= 500
{tipo="acesso"} | json | ClientHost = "203.0.113.7"
sum by (router) (count_over_time({tipo="acesso"} [5m]))
{projeto="traefik", tipo="traefik"} |= "acme"
{tipo="acesso"} | json | line_format `{{.RequestPath}} {{ divf .Duration 1000000 | printf "%.1f" }}ms`
```

A new site on the edge enters the `site` selector by editing the variable in
the JSON (the `query` of the `site` variable in `logs.json`).

## Telegram alerts

Grafana itself alerts on Telegram (no Alertmanager) and **notifies again when
the problem resolves**. Everything is provisioned from files in
`grafana/provisioning/alerting/`: `contato.yml` (the `telegram` contact point
and the notification policy), `regras.yml` (the rules) and `mensagem.yml` (the
message text).

| Alert | Fires when | Wait |
|---|---|---|
| Certificate expiring (Traefik) | `traefik_tls_certs_not_after` is under **20 days** | 0 |
| Certificate expiring (site) | the certificate seen from outside by blackbox is under **20 days** | 0 |
| Site down | `probe_success` = 0 | 5 min |
| High 5xx rate | more than **5%** of a service's responses are 5xx (10 min window) **and** the service has more than **0.05 req/s** | 10 min |
| VPS disk full | `/` above **85%** | 0 |
| VPS collection stopped | `traefik` or `node` job `down` | 5 min |
| Deploy failed (VPS) | `deploy_falhou` = 1 for any site (the `app` goes in the message); resolves when the next run succeeds | 0 |
| Deploy cron stopped | last cron run (`deploy_rodada_timestamp_seconds`) older than the `deploy_parado_min` limit, or the series vanished (5 min wait absorbs the homelab boot, while the tunnel is not up yet) | 5 min |
| GHCR token expiring (VPS) | the token of `docker login ghcr.io` on the VPS (`ghcr_token_expira_timestamp_seconds`, read from GitHub by the deploy cron) has exactly **30, 20, 10, 7, 5, 3, 2, 1 or 0** whole days left: one message per day value, never repeated, no "resolved" (contact point `telegram-sem-resolvido`, route `aviso=dias`). A renewed token moves the date, so nothing fires | 0 |

The stopped-cron threshold is `deploy_parado_min` (default 30 min), in the
`limites` block (thresholds) of `regras.yml`. If the whole VPS collection stops,
"VPS collection stopped" and "Deploy cron stopped" may fire together (accepted).

To see the two deploy alerts actually fire (force a failure on the VPS,
receive it on Telegram and watch it resolve), follow the
[forced-failure checklist](../traefik-default#checklist-manual-da-falha-forçada)
in the `traefik-default` README.

Each message states the severity, which alert, which certificate, site or
service with the current value, and since when (Brasília time):

```
🔴 CRITICAL · Site down
Site https://conantorres.dev has been down for more than 5 minutes (probe_success = 0)
🕐 since Oct 27 14:32
```

🔴 `critical`, 🟠 `warning`, ✅ resolved (with start → end). To change the text,
edit `mensagem.yml` and run `docker compose restart grafana`. The minimum
traffic threshold avoids alerting on a nearly idle service where 1 error in 3
requests gives 33% 5xx.

### Creating the bot and filling in `.env`

1. On Telegram, talk to [@BotFather](https://t.me/BotFather), send `/newbot`,
   pick a name and username and keep the **token** (`123456:ABC...`).
2. Open a chat with your bot (or add it to a group) and send any message, such
   as `/start`.
3. Find the **chat ID**: open `https://api.telegram.org/bot<TOKEN>/getUpdates`
   and look for `"chat":{"id":...}`. For a group the number is negative (e.g.
   `-100123...`).
4. Fill in `.env`: `TELEGRAM_BOT_TOKEN` and `TELEGRAM_CHAT_ID` (compose will
   not start without them; the token exists only in `.env`, which is not
   committed to git).
5. `docker compose up -d` (or `docker compose up -d grafana` if the stack was
   already running).

### Sending a test alert

In Grafana (`http://127.0.0.1:23000`): *Alerting → Contact points → telegram →
Test* (the "Test"/"Send test notification" button). If the message arrives on
Telegram, the bot, token and chat ID are right. If it does not:
`docker compose logs grafana | grep -i telegram` (a wrong token gives
`401`/`404`; a wrong chat ID, or a bot that never received a message from you,
gives `400`).

### Tuning the thresholds

The thresholds (20 days, 5%, 0.05 req/s, 85%) live in **one place only**: the
`limites` block at the top of `grafana/provisioning/alerting/regras.yml`. After
changing them, `docker compose restart grafana`. They are not in `.env` because
Grafana 13.2.3 does not substitute environment variables inside rules (only in
the contact point); tested and explained in the header of `regras.yml`. The
wait times (`for:`) are on each rule.

### Removing a rule

Removing a rule's block from `regras.yml` **does not delete it from Grafana**: a
rule that came from provisioning only goes away with a `deleteRules` in the
provisioning itself (through the API Grafana refuses with 409). Add to the file
a block with the rule's `orgId` and `uid` (the `uid` is the rule's `uid` field
in the file):

```yaml
deleteRules:
  - orgId: 1
    uid: cert-site
```

Step by step:

1. Remove the rule's block from `regras.yml` and add the `deleteRules` with the
   uids to delete.
2. `docker compose restart grafana`.
3. Check: `./grafana-api.sh GET /api/v1/provisioning/alert-rules | jq -r '.[].uid'`
   no longer lists the uid.
4. After the restart, remove the `deleteRules` from the file. If it stays,
   Grafana tries to delete that uid on every startup, including a rule you
   recreate with the same uid.

## Going live

The order for the first time (or after reinstalling the VPS). The steps are
manual; the smoke test replaces none of them.

**0. On the PC: publish the edge.** The VPS's `/opt/traefik` is a clone of the
GitHub repo; the node exporter and the `metricas` documentation only get there
after the merge of `feature/homelab-monitoring` into `traefik-default`'s `main`
and the `git push`. Run that repo's `testes/smoke.sh` first.

**1. On the VPS: node exporter on the edge.** It comes in the
`docker-compose.yml` of
[`traefik-default`](../traefik-default#painel-e-métricas-via-túnel-ssh):

```bash
cd /opt/traefik && git pull
docker compose up -d
docker compose ps                                   # node-exporter is up
curl -s http://127.0.0.1:9100/metrics | head -3     # answers on the loopback
sudo ss -ltnp | grep 9100                           # only 127.0.0.1:9100, never 0.0.0.0
```

**2. From the PC: port 9100 must not be visible from outside.** It has to fail
(timeout or connection refused):

```bash
curl -m 5 http://IP_DA_VPS:9100/metrics
```

**3. On the VPS: the `metricas` user.** Follow "Monitoramento a partir de outra
máquina" in the
[`traefik-default`](../traefik-default#monitoramento-a-partir-de-outra-máquina)
README (shell-less user, key restricted to ports 8082, 9100 and 3100, `sshd`
verification and the manual key test). The public key comes from step 1 of
"Tunnel to the VPS", below; generate it beforehand.

**4. On the PC: tunnel and stack.** Follow "Tunnel to the VPS" (key,
`known_hosts`, `.env`) and "Creating the bot and filling in `.env`" (Telegram);
then `docker compose up -d --build`.

**5. Verify everything** with the "Manual checklist".

## Manual checklist

Not automated: run it after going live and whenever you touch the VPS, the
tunnel or the bot.

- [ ] **Real tunnel with the targets `up`.** The `up` query (see "Querying
  Prometheus") shows the `sites`, `traefik` and `node` jobs with value `1`; the
  Traefik, Node Exporter Full and Sites dashboards show real VPS data.
- [ ] **The Loki data source responds.** In *Connections → Data sources → Loki
  → Test* (or *Explore* with the Loki source), the test is green and
  `{projeto="traefik"}` returns lines. If it errors on connection, check 3100
  in `authorized_keys` (`permitopen="127.0.0.1:3100"`) and
  `docker compose logs tunel`.
- [ ] **The `metricas` key refuses a shell.** `ssh -i chaves/id_tunel -o
  IdentitiesOnly=yes metricas@IP_DA_VPS` closes immediately (or "This account
  is currently not available.").
- [ ] **The `metricas` key refuses to forward to another port.** A tunnel to
  `127.0.0.1:8080` (the dashboard) gives `administratively prohibited` and
  `curl` fails, while the one to `127.0.0.1:8082` answers. The commands are in
  step 4 ("Teste do PC", the PC test) of "Monitoramento a partir de outra
  máquina" in the
  [`traefik-default`](../traefik-default#monitoramento-a-partir-de-outra-máquina)
  README.
- [ ] **The tunnel comes back by itself after suspending the PC.** Suspend the
  PC for more than a minute, wake it and wait 1 to 2 minutes: `traefik` and
  `node` return to `UP` with no intervention. If they do not,
  `docker compose logs tunel`.
- [ ] **Collection recovers after restarting Traefik.** On the VPS,
  `cd /opt/traefik && docker compose restart traefik`. The `traefik` target may
  drop for a few seconds and returns to `UP` by itself on the PC (the tunnel
  points to the VPS loopback, which does not change with the container;
  nothing to redo).
- [ ] **Dependabot read the configuration.** On GitHub, *Insights →
  Dependency graph → Dependabot* shows both ecosystems (`docker-compose` and `docker`)
  without errors; check it after the merge that touches
  `.github/dependabot.yml`.
- [ ] **The test alert arrives on Telegram.** See "Sending a test alert".

## Adding a site

Adding a site = adding one line to `prometheus/alvos/sites.yml` (always
`https://`). Prometheus rereads the file by itself within 1 minute, no restart.
The probe criteria are in `blackbox/blackbox.yml`: HTTPS with a valid
certificate, follows redirects, IPv4, accepts any 2xx.

## Smoke test

```bash
testes/smoke.sh
```

It brings the stack up with fake sites (one up, one with an untrusted
certificate, one redirect, one 500 and one that does not exist) and a fake
tunnel (the `tunel` service becomes an nginx serving Traefik and node exporter
`/metrics`, with no SSH; it includes a certificate expiring in 10 days, and
`tunel:3100` forwards to a real Loki, the `loki-falso` ("fake Loki"), where the
smoke injects sample lines). Through the Prometheus API it checks that the up
target gives `probe_success` 1 and the others 0, that the `traefik` and `node`
jobs are `up`, that the tunnel publishes no ports, that retention is 90 days
and that Prometheus does **not** answer on the PC's non-loopback IP. On
Grafana it checks that it is healthy, requires the password, listens only on
`127.0.0.1`, has the Prometheus and Loki data sources and the three
dashboards, that the main dashboards show data and that the Loki queries made
by Grafana itself return the injected lines, filtered by site (and that, with
Loki stopped, the rest of the stack stays up). On alerts, it checks that the
rules exist through the API, that the contact point and policy are right, that
the 10-day certificate fires and that the 5xx rule goes into pending for the
high-traffic service but not for the near-zero-traffic one. It also checks that
every service in the stack has a memory cap (`mem_limit`, criterion at the top
of `docker-compose.yml`) and that none was killed for lack of memory. No real
message is sent (fake token, and `api.telegram.org` pointed at `127.0.0.1`
only in the smoke). It tears everything down at the end, even on failure. It
uses the project `homelab-smoke`, `127.0.0.1:19090` (Prometheus) and
`127.0.0.1:13000` (Grafana): it runs with the real stack up, without stopping
or touching anything of it. Before starting, it checks that those ports are
free and, if one is busy, exits saying which (change them with
`PORTA_PROMETHEUS` and `PORTA_GRAFANA`). Any variable in `testes/smoke.env` can
be overridden this way, without editing the file: the environment takes
precedence over `testes/smoke.env`, which only provides the defaults (e.g.
`PORTA_PROMETHEUS=19191 testes/smoke.sh`). It takes about a minute.

To extend it (the next stages): a new check is a file
`testes/verificacoes/NN-name.sh`; a new fake service is an override in
`testes/compose/NN-name.yml`. Details in the header of `testes/smoke.sh`.
Without starting anything, `testes/docs.sh` checks the README's required
points.

## Pre-commit hook

The repository ships a versioned hook in `.githooks/pre-commit`. It runs in
seconds, without starting a container (the smoke test is left out), in this
order:

1. `bash -n` on the versioned `.sh` scripts;
2. `shellcheck` on those scripts, warning level and up (the *info* findings are
   single-quoted literals on purpose); if it is not installed, the hook warns
   that it skipped the step and carries on;
3. `testes/docs.sh`;
4. the isolated tests listed in `testes/isolados.txt` (currently
   `testes/grafana-api.sh`; no docker, no fixed ports). A new isolated test
   goes in that list and in the list above, and `docs.sh` enforces the README.

If a step fails, the commit is refused and the output says which.

Enable it once per clone:

```bash
git config core.hooksPath .githooks
```

Before committing, run the same steps by hand (or `.githooks/pre-commit`). In
an emergency, skip the hook with `git commit --no-verify`.

## Pinning and updating versions

Images are **pinned**, never `latest`: nothing changes on its own. Each tag
appears in a single file:

- `docker-compose.yml`: `prom/prometheus:vX.Y.Z`,
  `prom/blackbox-exporter:vX.Y.Z` and `grafana/grafana:X.Y.Z`;
- `tunel/Dockerfile`: `alpine:X.Y.Z` (autossh and ssh come from that Alpine
  version's packages);
- `testes/smoke.env`: `nginx:X.Y.Z-alpine` (only for the smoke's fake sites)
  and `grafana/loki:X.Y.Z` (the fake Loki, which repeats the edge Loki's tag).

Reference for the edge's Loki version (its only annotation in this repository;
`docs.sh` compares the smoke's `IMAGEM_LOKI` against it):

> Loki da borda: `grafana/loki:3.7.8`

The two smoke-only images live in `testes/smoke.env` and are **not** part of
the Dependabot PR, by decision: the `docker-compose` ecosystem only reads files
whose name contains "compose" and does not read `.env`, and the `${IMAGEM_*:?}`
in the `testes/compose/` files is invisible to it. Making them literal would
require renaming the files and repeating nginx in three places, and the result
could only be verified on GitHub after the merge. In exchange, nginx is
test-only and `testes/docs.sh` checks the fake Loki's tag against the note
above: it fails if the two diverge.

### Via the Dependabot PR

Once a month Dependabot (`.github/dependabot.yml`) opens one PR per ecosystem
with the images that had a new version published at least 14 days ago: one for
compose (Prometheus, blackbox, Grafana) and another for the Alpine in
`tunel/Dockerfile`. Nothing is applied on its own. For each PR:

1. Read the release notes the PR brings.
2. Keep the real stack up: the smoke test uses ports 19090 and 13000 and
   coexists with it.
3. Run `testes/smoke.sh` on the PR's branch. On the Alpine PR, also run
   `docker compose build tunel` (the smoke does not use the tunnel image).
4. Approve and merge.
5. Apply: `docker compose pull`, `docker compose build` and
   `docker compose up -d`; then `docker compose ps && docker compose logs
   --tail 50`.

The Loki PR only arrives in `traefik-default`. When approving it, update here,
at the same time, the `IMAGEM_LOKI` in `testes/smoke.env` and the "Loki da
borda" note above; `testes/docs.sh` fails until the two match.

### By hand

The procedure below remains valid for updating without Dependabot.

To update, deliberately:

1. Read the release notes
   (<https://github.com/prometheus/prometheus/releases>,
   <https://github.com/prometheus/blackbox_exporter/releases>,
   <https://github.com/grafana/grafana/releases>,
   <https://alpinelinux.org/releases/>).
2. Test first: change the tag in its file (only there) and run
   `testes/smoke.sh` (uses `127.0.0.1:19090`, with the real stack up). The
   smoke does not use the tunnel image (it swaps it for a fake target): for
   Alpine, run `docker compose build tunel` and, after step 3, check the
   `traefik` and `node` jobs are `UP` and `docker compose logs tunel`.
3. Apply:
   ```bash
   docker compose pull           # ready-made images
   docker compose up -d --build  # --build rebuilds the tunnel
   docker compose ps && docker compose logs --tail 50
   ```
4. To roll back, restore the previous tag and repeat the `up -d`.

`.env`, the keys (`chaves/`) and the `prometheus-dados` volume stay out of git
and survive the image swap.
