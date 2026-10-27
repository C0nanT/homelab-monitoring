# Observabilidade da VPS rodando no meu PC

Status: ready-for-agent

## Problem Statement

Tenho uma única VPS (Hetzner, 2 vCPU, 3,7 GB) servindo `conantorres.dev` e `bbcontainermodular.com` atrás do Traefik do repositório `traefik-default`. Hoje não tenho como saber, sem entrar na VPS, se um site caiu, se está lento, se está devolvendo erro, se um certificado está perto de vencer ou se o disco está enchendo. O Traefik já expõe métricas Prometheus em `127.0.0.1:8082` da VPS, mas nada as coleta.

Não quero rodar Prometheus e Grafana na própria VPS: ela é a única máquina, tem pouca memória para isso, e um monitor que roda no mesmo servidor que monitora cai junto com ele e não avisa que caiu.

Há uma data concreta em risco: o token da Cloudflare usado no DNS-01 expira em 26/10/2027. Se ninguém lembrar, a renovação do certificado curinga do `conantorres.dev` passa a falhar em silêncio e o site quebra quando o certificado vencer.

Também quero que o projeto sirva de estudo de Prometheus, Grafana e exporters, no mesmo espírito do `traefik-default`.

## Solution

Um repositório novo, `homelab-monitoring`, com uma pilha Docker Compose que roda no meu PC: Prometheus, Grafana, blackbox exporter e um container de túnel SSH (autossh). O túnel liga, de forma permanente e com reconexão automática, as portas de métricas que a VPS publica só no loopback (Traefik em 8082 e node exporter em 9100) à rede interna da pilha. O Prometheus coleta essas métricas pelo túnel; o blackbox testa os sites pela internet, de fora da VPS, como um visitante. O Grafana mostra painéis já provisionados e envia alertas para o Telegram.

Na VPS, o `traefik-default` ganha um node exporter (CPU, memória, disco, rede do host), ouvindo só em `127.0.0.1:9100`, e um usuário `metricas` sem shell cuja chave SSH só pode abrir túnel para essas duas portas. Nada novo é publicado na internet.

~~Como a pilha só funciona com o PC ligado, um monitor externo gratuito (UptimeRobot) fica como alarme 24/7 de "site fora do ar", independente do meu PC.~~ Descartado em 2026-10-27: a pilha é 100% local (veja Further Notes).

## User Stories

1. Como dono da VPS, quero subir toda a observabilidade no meu PC com um único `docker compose up -d`, para não gastar recursos da VPS.
2. Como dono da VPS, quero que a pilha volte sozinha quando o PC liga, para não depender de lembrar de subi-la.
3. Como dono da VPS, quero que o túnel até a VPS reconecte sozinho depois de suspensão, troca de rede ou reinício da VPS, para não ter buracos longos nos dados por causa de um túnel caído.
4. Como dono da VPS, quero que o túnel use um usuário dedicado `metricas`, sem shell e com chave restrita às portas 8082 e 9100 do loopback, para que um vazamento da chave só permita ler métricas.
5. Como dono da VPS, quero que nenhuma porta nova seja publicada na interface pública da VPS, para manter o modelo de segurança atual (só 22, 80 e 443).
6. Como dono da VPS, quero que a chave privada do túnel e o token do bot do Telegram fiquem fora do git, para não vazar segredos ao publicar o repositório.
7. Como dono da VPS, quero que o Prometheus colete as métricas do Traefik pelo túnel, para ver requisições, erros e latência por serviço e por entrada.
8. Como dono da VPS, quero ver, por certificado, quantos dias faltam para vencer (`traefik_tls_certs_not_after`), para saber se a renovação automática está funcionando.
9. Como dono da VPS, quero um alerta quando qualquer certificado tiver menos de 20 dias de validade, para agir antes de o site quebrar (inclusive se o token da Cloudflare expirar).
10. Como dono da VPS, quero que o blackbox exporter teste cada site por HTTPS a partir do meu PC, para saber se ele responde de verdade para quem está fora.
11. Como dono da VPS, quero que o blackbox teste a raiz e o `www` de cada domínio e os endpoints de health dos sites, para pegar tanto o site fora quanto o redirecionamento quebrado.
12. Como dono da VPS, quero que o blackbox falhe se a resposta não vier por HTTPS válido, para pegar certificado inválido ou o certificado padrão do Traefik sendo servido.
13. Como dono da VPS, quero ver o vencimento do certificado que o visitante recebe de fato (`probe_ssl_earliest_cert_expiry`), para comparar com o que o Traefik diz ter.
14. Como dono da VPS, quero um alerta quando um site ficar fora por mais de alguns minutos, para não ser avisado por um soluço de rede.
15. Como dono da VPS, quero ver o tempo de resposta de cada site ao longo do tempo, com a parte do TLS separada, para notar lentidão.
16. Como dono da VPS, quero um alerta quando a taxa de respostas 5xx de um serviço passar de um limite, para saber de erros que o visitante vê mesmo com o site "no ar".
17. Como dono da VPS, quero métricas de CPU, memória, disco e rede da VPS via node exporter, para saber quando o servidor está apertado.
18. Como dono da VPS, quero um alerta quando o disco da VPS passar de 85%, para limpar antes de os containers pararem.
19. Como dono da VPS, quero um alerta quando o túnel ou a coleta da VPS ficar fora por mais de alguns minutos com o PC ligado, para distinguir "VPS caiu" de "meu túnel caiu" pelo conjunto de sinais (blackbox ok + coleta fora = túnel).
20. Como dono da VPS, quero receber os alertas no Telegram, para ser avisado no celular.
21. Como dono da VPS, quero que o alerta também avise quando volta ao normal, para não ter que conferir à mão.
22. Como dono da VPS, quero o Grafana abrindo já com a fonte de dados Prometheus e os painéis prontos, sem clicar nada, para recriar tudo do zero só com o repositório.
23. Como dono da VPS, quero um painel do Traefik, um painel do host (node exporter) e um painel dos sites (blackbox: no ar, latência, status, validade do certificado), para ter as três visões separadas.
24. Como dono da VPS, quero que as regras de alerta e os painéis fiquem versionados como arquivos, para revisar mudanças pelo git.
25. Como dono da VPS, quero Grafana e Prometheus acessíveis só em `127.0.0.1` do meu PC, para não expô-los na minha rede local.
26. Como dono da VPS, quero que o Grafana peça login com senha definida no `.env`, para não ficar com `admin/admin`.
27. Como dono da VPS, quero um histórico de pelo menos 90 dias no Prometheus, para comparar semanas e meses.
28. Como dono da VPS, quero que os dados do Prometheus e do Grafana sobrevivam a `docker compose down` e a atualizações de imagem, para não perder histórico.
29. Como dono da VPS, quero versões fixas de todas as imagens, com um roteiro para atualizá-las, como no `traefik-default`, para não ter mudanças surpresa.
30. ~~(descartada em 2026-10-27)~~ Como dono da VPS, quero um monitor externo (UptimeRobot) para os dois domínios, com aviso no Telegram ou e-mail, para ser avisado de queda mesmo com o PC desligado.
31. Como dono da VPS, quero um README que explique a arquitetura (PC → túnel → loopback da VPS; blackbox → internet) e por que cada peça existe, para servir de estudo.
32. Como dono da VPS, quero no README um checklist de instalação no lado da VPS (usuário `metricas`, chave restrita, node exporter), para refazer em outra VPS.
33. Como dono da VPS, quero no README a limitação explícita de que o uptime medido pela pilha só vale para as horas em que o PC estava ligado, para não ler o número errado.
34. Como dono da VPS, quero adicionar um site novo ao monitoramento editando só a lista de alvos do blackbox, para que plugar um projeto continue simples.
35. Como dono da VPS, quero um smoke test local que sobe a pilha com alvos falsos no lugar do túnel e da internet, para validar a configuração sem depender da VPS.
36. Como dono da VPS, quero que o túnel manual do painel do Traefik (`ssh -L 8080 -L 8082`) continue funcionando ao mesmo tempo que a pilha, para não ter conflito de portas no PC.

## Implementation Decisions

**Repositório novo `homelab-monitoring`** (no PC, `/home/conan/projects/homelab-monitoring`)
- Uma pilha Docker Compose com quatro serviços: `prometheus`, `grafana`, `blackbox` e `tunel` (autossh).
- O túnel roda como container dentro da pilha, não como serviço systemd no host. Assim o Prometheus alcança as portas encaminhadas pelo nome do serviço na rede interna, sem `network_mode: host`, sem portas no loopback do PC e sem conflito com o túnel manual do painel (história 36). O ciclo de vida é o mesmo da pilha (`restart: unless-stopped`).
- Túnel: autossh com `ExitOnForwardFailure`, keepalive (`ServerAliveInterval`/`ServerAliveCountMax`) e encaminhamentos ouvindo em todas as interfaces do container (só a rede interna da pilha os alcança). A chave privada e o `known_hosts` da VPS são montados só para leitura a partir de uma pasta ignorada pelo git. `StrictHostKeyChecking` ligado, com `known_hosts` fixo.
- Prometheus: três jobs. `traefik` (pelo túnel, porta 8082), `node` (pelo túnel, porta 9100) e `sites` (blackbox, padrão `/probe` com relabel `target`→`instance`). Retenção por tempo de 90 dias. Volume nomeado para os dados. Publicado só em `127.0.0.1:9090`.
- Blackbox: um módulo HTTP que exige HTTPS válido (`fail_if_not_ssl`), segue redirecionamentos, usa IPv4 e aceita 2xx. Alvos iniciais: raiz e `www` de `conantorres.dev` e `bbcontainermodular.com`, mais os endpoints de health dos sites que tiverem um (o bbcontainer usa `/api/health`). A lista de alvos fica num único lugar, separada do resto da config (história 34).
- Grafana: provisionamento por arquivo de fonte de dados (Prometheus, como padrão), painéis, regras de alerta, contact point Telegram e política de notificação. Senha de admin e credenciais do Telegram vêm do `.env`. Volume nomeado para os dados. Publicado só em `127.0.0.1:3000`. Alertas pelo próprio Grafana (sem Alertmanager).
- Painéis: Traefik e Node Exporter a partir dos painéis públicos da comunidade, salvos como JSON no repositório (não importados por ID em tempo de execução), e um painel próprio "Sites" com os dados do blackbox.
- Regras de alerta (limites iniciais, ajustáveis):
  - certificado com menos de 20 dias, por `traefik_tls_certs_not_after` e por `probe_ssl_earliest_cert_expiry`;
  - `probe_success` = 0 por 5 minutos;
  - taxa de 5xx por serviço acima de 5% por 10 minutos (com tráfego mínimo, para não disparar com uma requisição só);
  - disco da VPS acima de 85%;
  - job `traefik` ou `node` com `up` = 0 por 5 minutos (túnel ou VPS);
  - alertas enviam também a resolução.
- `.env.example` versionado com todas as variáveis (senha do Grafana, token do bot, chat ID do Telegram, host e usuário do túnel); `.env` e a pasta de chaves no `.gitignore`.
- Todas as imagens com tag de versão fixa; README com roteiro de atualização, no estilo do "Fixar e atualizar a versão do Traefik" do `traefik-default`.
- Idioma: README, comentários e mensagens em português, como no `traefik-default`; nomes de serviços e pastas podem seguir os nomes das ferramentas.

**Mudanças no `traefik-default`** (lado da VPS)
- Novo serviço node exporter no `docker-compose.yml` da borda, com tag fixa, `network_mode: host`, `pid: host`, raiz do host montada só para leitura e escutando apenas em `127.0.0.1:9100`. Fica fora da rede `proxy`: os sites vizinhos não o alcançam.
- README ganha uma seção "Monitoramento a partir de outra máquina":
  - criar o usuário `metricas` sem shell e sem senha;
  - colocar a chave pública em `authorized_keys` com `restrict,port-forwarding,permitopen="127.0.0.1:8082",permitopen="127.0.0.1:9100"`;
  - conferir que o `sshd` permite encaminhamento TCP para esse usuário;
  - aponta para o repositório `homelab-monitoring`.
- A seção "Próximos passos → Grafana + Prometheus" do README é atualizada para apontar para esse arranjo.
- O `HANDOFF.md` registra a nova peça.

**Fora dos repositórios**
- UptimeRobot (plano gratuito): monitores HTTPS para `https://conantorres.dev` e `https://bbcontainermodular.com`, com aviso por Telegram ou e-mail. Configurado à mão, com o passo a passo no README do `homelab-monitoring`.
- Bot do Telegram criado pelo BotFather; token e chat ID vão só para o `.env` local.

## Testing Decisions

- Um bom teste verifica o comportamento observável da pilha (o que a API do Prometheus, o blackbox e o Grafana respondem), não a estrutura dos arquivos de config.
- Pontos de teste acordados:
  - **Smoke test local do `homelab-monitoring`**: um script que sobe a pilha com um override de compose que troca o container do túnel por um alvo falso, servindo um `/metrics` fixo com séries do Traefik e do node exporter (inclusive uma `traefik_tls_certs_not_after` vencendo em menos de 20 dias), e troca os alvos do blackbox por um site HTTPS local (no ar) e um endereço que não responde (fora). Ele verifica:
    - pela API do Prometheus, que os jobs `traefik` e `node` estão `up`;
    - que o blackbox reporta `probe_success` 1 para o alvo no ar e 0 para o alvo fora;
    - que o Grafana sobe saudável, com a fonte de dados, os três painéis e as regras de alerta provisionados (pela API do Grafana);
    - que a regra de certificado entra em estado de disparo com a série falsa;
    - que Prometheus e Grafana não respondem fora de `127.0.0.1`;
    - no final, derruba tudo, mesmo se algo falhar.
  - **Extensão do smoke do `traefik-default`**: uma verificação nova confere que o node exporter responde em `127.0.0.1:9100` e não responde no IP não-loopback da máquina nem pela rede `proxy` (container vizinho).
  - **Checklist manual** no README (não automatizado):
    - túnel real até a VPS, com os alvos `up`;
    - a chave do `metricas` recusa shell e encaminhamento para outra porta (ex.: 8080);
    - alerta de teste chega no Telegram;
    - monitores do UptimeRobot verdes.
- Módulos testados: a pilha do `homelab-monitoring` (compose e configs de Prometheus, blackbox e Grafana) e o node exporter na pilha de borda do `traefik-default`.
- Prior art: `testes/smoke.sh` e `testes/lib.sh` do `traefik-default` (sobe a pilha, verifica por fora com `curl`, derruba no final, contador de falhas, verificações extensíveis por pasta). O smoke novo segue o mesmo formato e estilo.

## Out of Scope

- Rodar Prometheus ou Grafana na VPS.
- Alertmanager (os alertas ficam no Grafana).
- Logs centralizados (Loki/Promtail) e tracing.
- cAdvisor e métricas por container.
- Métricas internas dos sites (bbcontainer, conan-torres); só o que se vê pelo Traefik e pelo blackbox.
- Monitoramento 24/7 (pilha 100% local; com o PC desligado, ninguém vigia os sites).
- Automatizar a configuração do UptimeRobot ou do bot do Telegram.
- Ligar `addRoutersLabels` no Traefik (métricas por router); as por serviço bastam por agora.
- Acesso ao Grafana de fora do PC (celular, outra máquina).

## Further Notes

- **Mudança em relação à conversa:** a ideia inicial era autossh como serviço systemd do usuário no PC. A spec troca por um container na pilha, para evitar portas no loopback do PC, conflito com o túnel manual do painel (8082) e a configuração de `linger`. Se preferir systemd, só muda o serviço `tunel`.
- **Palpites assumidos:** retenção de 90 dias, limites dos alertas (20 dias, 5 min, 5% de 5xx, 85% de disco) e alertas pelo Grafana em vez de Alertmanager. Todos são ajustáveis sem mudar a arquitetura.
- **Uptime enganoso:** o `probe_success` medido pela pilha só cobre as horas com o PC ligado.
- **Decisão de 2026-10-27:** UptimeRobot descartado. A pilha fica 100% local; com o PC desligado não há aviso de queda, e isso é aceito.
- **Token da Cloudflare** expira em 26/10/2027 (ver `HANDOFF.md` do `traefik-default`). O alerta de certificado com menos de 20 dias é a rede de segurança se a troca for esquecida.
- O repositório `homelab-monitoring` foi criado vazio (`git init`, branch `main`) só com esta spec; ainda sem remoto no GitHub.
