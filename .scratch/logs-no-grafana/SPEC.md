# Logs dos sites no Grafana

Status: ready-for-agent

## Problem Statement

Hoje os logs de `conantorres.dev` e `bbcontainermodular.com` só existem no Docker da VPS. Para ver qualquer coisa preciso entrar por SSH e rodar `docker compose logs` com `grep`, em dois lugares diferentes: na pilha de borda, para o log de acesso do Traefik, e na pasta de cada site, para a saída da aplicação.

E mesmo assim o histórico é curto e frágil:

- O log do conan-torres tem no máximo ~3 MB (3 arquivos de 1 MB).
- Os logs somem sempre que o container é recriado, e o cron de atualização faz isso a cada deploy.
- Quando um alerta chega no Telegram ("Site fora do ar", "Taxa de 5xx alta"), não tenho como ver no Grafana o que o site estava registrando naquela hora. Se demoro a olhar, a evidência já foi embora.

Também quero que isto sirva de estudo de Loki e de coleta de logs, como o resto do homelab serve de estudo de Prometheus e Grafana.

## Solution

**Na VPS (pilha de borda, `traefik-default`):**

- Um coletor (Grafana Alloy) lê os logs de todos os containers da VPS e manda para um Loki que roda na própria VPS. Os dois ficam na pilha de borda, como o node exporter.
- O Loki guarda **30 dias** e escuta só no loopback da VPS (`127.0.0.1:3100`).
- Por ficar na VPS, a coleta funciona 24/7, inclusive com o PC desligado.

**No PC (`homelab-monitoring`):**

- O túnel SSH ganha mais um encaminhamento (3100).
- O Grafana ganha uma fonte de dados Loki e um painel **Logs**. Nele escolho o site e vejo, na mesma tela, a saída da aplicação e o log de acesso do Traefik daquele site, com busca por texto e o período que eu quiser.
- Também posso usar o *Explore* do Grafana para consultas livres.

## User Stories

1. Como dono da VPS, quero ver os logs da aplicação do `conantorres.dev` no Grafana, para não precisar entrar por SSH.
2. Como dono da VPS, quero ver os logs da aplicação do `bbcontainermodular.com` no Grafana, para não precisar entrar por SSH.
3. Como dono da VPS, quero ver o log de acesso do Traefik separado por site, para saber quem acessou o quê e qual status recebeu.
4. Como dono da VPS, quero escolher o site num seletor do painel, para não montar a consulta à mão.
5. Como dono da VPS, quero buscar um texto nos logs (ex.: "Error", um caminho, um IP), para achar rápido uma ocorrência.
6. Como dono da VPS, quero escolher o período (última hora, ontem, semana passada), para investigar um problema que já passou.
7. Como dono da VPS, quero que os logs fiquem guardados por 30 dias, para investigar problemas recentes mesmo depois de um deploy.
8. Como dono da VPS, quero que os logs continuem sendo coletados com o PC desligado ou suspenso, para não perder nada do período em que eu não estava olhando.
9. Como dono da VPS, quero que os logs sobrevivam à recriação dos containers dos sites (cron de deploy), para não perder a evidência de um erro.
10. Como dono da VPS, quero que um site novo plugado na borda tenha os logs coletados sem configuração extra, para não precisar lembrar de mexer na coleta.
11. Como dono da VPS, quero ver também os logs do próprio Traefik (erros de ACME, de roteamento), para investigar falhas de certificado.
12. Como dono da VPS, quero ver no painel quantas linhas de erro cada site produziu ao longo do tempo, para notar um aumento sem ler linha por linha.
13. Como dono da VPS, quero ver no painel a quantidade de respostas por status (2xx, 4xx, 5xx) de cada site a partir do log de acesso, para cruzar com o alerta de 5xx.
14. Como dono da VPS, quero que o IP real do visitante apareça no log de acesso (o `ClientHost` já vem certo da Cloudflare), para saber de onde veio uma requisição.
15. Como dono da VPS, quero que o Loki não seja alcançável pela internet nem pelos containers dos sites, para os logs (com IPs de visitantes) não vazarem.
16. Como dono da VPS, quero que o coletor acesse o Docker só para leitura, para um bug ou falha nele não dar controle da VPS.
17. Como dono da VPS, quero que o usuário `metricas` continue sem shell e só possa abrir os encaminhamentos permitidos (agora 8082, 9100 e 3100), para o túnel continuar restrito.
18. Como dono da VPS, quero que o Loki e o coletor tenham limites de memória e de disco conhecidos, para não derrubarem os sites numa VPS de 3,7 GB.
19. Como dono da VPS, quero que uma rajada de logs (ex.: varredura de bots) não estoure o disco da VPS, para a coleta nunca ser a causa de queda.
20. Como dono da VPS, quero que o painel Logs venha provisionado por arquivo, como os outros, para reinstalar a pilha e ter tudo igual sem clicar.
21. Como dono da VPS, quero que a fonte de dados Loki venha provisionada por arquivo, para não configurar nada na tela.
22. Como dono da VPS, quero que, com o túnel fora, o painel Logs mostre erro de conexão claro e o resto do Grafana continue funcionando, para uma falha não derrubar tudo.
23. Como dono da VPS, quero um passo a passo no README para subir o Loki e o coletor na VPS e liberar a porta 3100 no `authorized_keys`, para fazer a mudança sem adivinhar.
24. Como dono da VPS, quero smoke tests nos dois repositórios cobrindo a coleta e a consulta, para mudar versões sem medo.
25. Como dono da VPS, quero as versões do Loki e do Alloy fixas (sem `latest`), para uma atualização nunca entrar sem eu saber.
26. Como dono da VPS, quero entender pelos comentários dos arquivos como funciona a coleta (rótulos, retenção, LogQL), para que o projeto sirva de estudo.
27. Como dono da VPS, quero saber pelo painel de Host quanto disco o Loki está usando, para ajustar a retenção se precisar.

## Implementation Decisions

**Onde cada peça roda**
- Loki e Alloy entram na **pilha de borda (`traefik-default`)**, ao lado do node exporter.
- Grafana, fonte de dados e painel ficam no `homelab-monitoring`.
- Segue o mesmo padrão já usado: a VPS expõe só no loopback, e o PC busca pelo túnel SSH.

**Loki**
- Modo monolítico (um processo) com armazenamento em sistema de arquivos, num volume nomeado da pilha de borda.
- Publicado só em `127.0.0.1:3100` do host. Fica em rede própria: fora da rede `proxy`, então nenhum site o alcança.
- Sem autenticação (`auth_enabled: false`): a proteção é o loopback mais o túnel restrito, a mesma das métricas.
- Retenção de **30 dias** com o compactor ligado. Limites de ingestão (taxa e rajada por stream) configurados para que uma enxurrada de logs seja descartada, e não encha o disco.
- Limite de memória do container definido. Healthcheck pelo endpoint `/ready`.

**Alloy (coletor)**
- Descobre os containers pela API do Docker, **somente leitura**, passando pelo `docker-socket-proxy` que já existe. O socket bruto nunca é montado no Alloy.
- O proxy já libera `CONTAINERS`, que cobre a leitura dos logs. O Alloy entra na rede `socket`, e o comentário do compose que diz que essa rede é "só entre o Traefik e o socket-proxy" precisa ser atualizado.
- Coleta **todos os containers** da VPS: os sites e a própria borda. Site novo entra sozinho.
- Rótulos (labels) fixos e de baixa cardinalidade:
  - `projeto` (projeto do compose, ex.: `conan-torres`, `bbcontainer`, `traefik`)
  - `servico` (serviço do compose, ex.: `web`, `app`, `traefik`)
  - `stream` (stdout/stderr)
- **Log de acesso do Traefik:** as linhas JSON de acesso são separadas das linhas de log do próprio Traefik por um rótulo `tipo` (`acesso` | `traefik`). Para filtrar por site no log de acesso, o rótulo é derivado do `RouterName` (conjunto fechado: os routers configurados), **nunca** do `RequestHost`. Host vem do cliente, e bots mandando qualquer Host explodiriam a cardinalidade.
- Os demais campos (status, caminho, `ClientHost`, duração) ficam no corpo JSON e são extraídos na consulta com LogQL (`| json`), não viram rótulo.
- O Alloy escuta só internamente: sem porta publicada, ou sua interface de depuração só no loopback.

**Túnel e usuário `metricas`**
- O container `tunel` encaminha também `127.0.0.1:3100` da VPS para `tunel:3100` na rede da pilha.
- O healthcheck do túnel passa a conferir também a 3100.
- A linha do `authorized_keys` do `metricas` ganha `permitopen="127.0.0.1:3100"`. É um passo manual na VPS, documentado nos dois READMEs.

**Grafana**
- Fonte de dados Loki provisionada por arquivo (uid fixo `loki`, URL `http://tunel:3100`). O Prometheus continua como fonte padrão.
- Painel novo **Logs**, feito para o projeto e provisionado por arquivo, como o Sites:
  - variável `site` com os valores de `projeto` dos sites (exclui a borda por padrão; a borda vira uma opção);
  - caixa de busca de texto;
  - painel de logs da aplicação do site;
  - painel do log de acesso daquele site (status, método, caminho, `ClientHost`, duração);
  - série de linhas com erro (stderr ou nível de erro) ao longo do tempo;
  - respostas por classe de status (2xx/3xx/4xx/5xx) contadas a partir do log de acesso.
- A partir dos painéis "Sites" e "Traefik" é possível chegar ao painel Logs, com um link no topo.

**Versões e recursos**
- Versões exatas de Loki e Alloy, fixadas na implementação (a estável mais recente na data, conferida), registradas no README como as outras.
- Orçamento na VPS: Loki mais Alloy na ordem de algumas centenas de MB de RAM no total. O disco é limitado pela retenção mais os limites de ingestão.

**Documentação**
- README do `traefik-default`: o que são o Loki e o Alloy na borda, as portas, a retenção, como liberar a 3100 para o `metricas` e como consultar direto na VPS em caso de emergência.
- README do `homelab-monitoring`: seção "Logs" (painel, Explore, exemplos de LogQL) e o checklist de subida.
- HANDOFF do `traefik-default`: um item novo.

## Testing Decisions

- **O que é um bom teste aqui:** comportamento visto de fora, com as ferramentas que o usuário usaria: uma linha de log escrita por um container aparece numa consulta ao Loki com os rótulos certos, e o Grafana consegue consultá-la. Nada de conferir chaves internas da configuração do Alloy ou do Loki.
- **Seam 1, smoke do `traefik-default`** (`testes/smoke.sh`): sobe a borda com Loki e Alloy.
  - Um container de teste numa pasta de projeto escreve uma linha marcada. Uma consulta em `127.0.0.1:3100` acha essa linha com `projeto`/`servico` corretos.
  - Uma requisição pelo Traefik gera uma linha de acesso com `tipo=acesso` e o rótulo do router.
  - Um container na rede `proxy` **não** alcança o Loki.
  - O Alloy **não** consegue escrever na API do Docker (ex.: parar um container é recusado pelo proxy).
  - A 3100 não está publicada fora do loopback.
- **Seam 2, smoke do `homelab-monitoring`** (`testes/smoke.sh`):
  - O túnel falso passa a servir também um Loki falso em `tunel:3100` (Loki real, com linhas de exemplo injetadas pela API de push).
  - A fonte de dados `loki` está provisionada e responde.
  - O painel Logs existe, e as consultas dele (pela API do Grafana) devolvem as linhas injetadas, filtradas pelo site.
- **Arte prévia:**
  - `traefik-default`: `testes/verificacoes/04-logs-e-metricas.sh` (log de acesso e X-Forwarded-For) e `06-node-exporter.sh` (porta só no loopback e inalcançável pela rede `proxy`).
  - `homelab-monitoring`: `testes/fixtures/tunel-falso/` mais `testes/compose/03-tunel-falso.yml` (serviço que finge ser o túnel) e `testes/verificacoes/04-grafana.sh` (datasources e painéis pela API).
- `testes/docs.sh` dos dois repos ganha checagens das seções novas do README.
- A subida real na VPS segue como checklist manual, como no ticket 06 do monitoramento.

## Out of Scope

- Alertas baseados em logs (regras LogQL no Grafana). Pode vir depois, já com os dados disponíveis.
- Logs da pilha do próprio PC (Prometheus, Grafana, túnel).
- Logs do sistema da VPS (journald, sshd, cron de atualização em `/var/log/atualizar-apps.log`).
- Importar os logs que existiam antes da coleta começar.
- Backup dos dados do Loki.
- Mudar o formato de log das aplicações (logs estruturados no conan-torres ou no bbcontainer).
- Traces (Tempo) e métricas derivadas de logs gravadas no Prometheus.
- Acesso ao Loki por outra máquina que não o PC via túnel.

## Further Notes

- **Decisões do usuário (2026-10-27):** Loki na VPS em vez de no PC (captura 24/7, mesmo com o PC desligado), logs da aplicação e de acesso, retenção de 30 dias, testes nos dois smokes existentes.
- **Muda a regra "monitoramento fora da VPS".** Até agora, só exporters leves ficavam na VPS. O Loki é o primeiro armazenamento de dados de monitoramento ali. Foi escolhido porque o log nasce na VPS e se perderia com o PC desligado. Registrar isso na SPEC do `traefik-default` e no HANDOFF.
- **Dados pessoais:** o log de acesso guarda o IP real dos visitantes por 30 dias, na VPS do próprio dono. As aplicações não devem logar segredos. Atenção ao `READER_DEBUG` do conan-torres: ligado, ele pode registrar dados sensíveis do leitor; conferir antes de ligar com a coleta ativa.
- **Ordem de subida, igual à do monitoramento:**
  1. merge e push do `traefik-default`;
  2. na VPS, `git pull` e `up -d` em `/opt/traefik`;
  3. liberar a 3100 no `authorized_keys`;
  4. no PC, subir o `homelab-monitoring` atualizado.
- O rotacionamento do Docker (`max-size`/`max-file`) continua valendo e não interfere: o Alloy lê em tempo real pela API, antes de a linha ser descartada pela rotação.
