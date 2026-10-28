# Atualização das imagens Docker por PR do Dependabot (traefik-default e homelab-monitoring)

Status: ready-for-agent

Vale para dois repositórios: **traefik-default** (a borda, na VPS) e **homelab-monitoring** (a pilha do PC). Os sites (conantorres.dev, bbcontainer) já usam o Dependabot para os pacotes npm e ficam fora desta spec.

## Problem Statement

As imagens dos dois repositórios estão fixadas em tags exatas, sem `latest`:

- **Borda:** Traefik, socket-proxy, node exporter, BusyBox, Loki, Alloy e o whoami do exemplo.
- **Pilha do PC:** Prometheus, blackbox, Grafana, o Alpine do túnel e as imagens que só o smoke usa (nginx e o Loki falso).

Nada avisa quando sai uma versão nova, nem quando ela traz correção de segurança. Hoje, atualizar depende de lembrar de olhar as notas de versão de cada projeto, uma por uma.

O Dependabot está ligado nos dois repositórios, mas só para alertas. Esses alertas não cobrem tag de imagem Docker, então na prática ninguém está olhando essas imagens.

## Solution

O Dependabot abre **um PR por mês em cada repositório** com as imagens que tiveram versão nova. Só entram versões publicadas há pelo menos 14 dias, a mesma regra de duas semanas já usada nas atualizações à mão.

O dono lê as notas de versão, roda o smoke localmente (não há CI) e aprova o PR. Na borda, o deploy continua como hoje: `git pull` e `up -d` na VPS.

As tags que só existem nos testes passam a ser lidas pelo Dependabot, ou, se não houver como, são vigiadas por um teste. Assim o Loki falso do smoke não fica para trás em relação ao Loki da borda.

## User Stories

1. Como dono da VPS, quero um PR quando sair versão nova do Traefik, para não ficar numa versão com falha conhecida sem saber.
2. Como dono da VPS, quero o mesmo para o Loki, o Alloy, o node exporter, o socket-proxy e o BusyBox.
3. Como dono do PC, quero o mesmo para o Prometheus, o blackbox e o Grafana.
4. Como dono do PC, quero um PR quando sair versão nova do Alpine usado na imagem do túnel, para o ssh e o autossh receberem correções.
5. Como dono, quero só versões com pelo menos 14 dias de publicadas, para uma versão quebrada ser corrigida antes de chegar até mim.
6. Como dono, quero um PR por mês em cada repositório, com as imagens juntas, para revisar tudo de uma vez e não a cada semana.
7. Como dono, quero que o PR diga qual tag mudou e mostre as notas de versão, para decidir sem caçar o changelog.
8. Como dono, quero que o Dependabot nunca proponha as versões `.0` do BusyBox, que são instáveis, para a borda ficar só na linha estável.
9. Como dono, quero que as tags com sufixo continuem com o sufixo (`-musl` do BusyBox, `-alpine` do nginx), para não trocar de variante sem querer.
10. Como dono, quero que as tags do smoke (o nginx dos sites falsos e o Loki falso) também sejam atualizadas, para o smoke testar o mesmo que roda de verdade.
11. Como dono, quero que o Loki falso do smoke fique na mesma tag do Loki da borda. Se o Dependabot não conseguir mantê-las juntas, quero um teste que falhe quando divergirem. Assim um PR da borda não deixa o smoke do homelab desatualizado sem eu perceber.
12. Como dono, quero que o README de cada repositório diga como revisar um PR do Dependabot: o que ler, qual smoke rodar e como aplicar (na VPS, no caso da borda).
13. Como dono, quero que o README diga que um PR do Loki chega nos dois repositórios e que os dois devem ser aprovados juntos, para os dois Lokis não divergirem.
14. Como dono, quero continuar podendo atualizar uma imagem à mão a qualquer momento, sem esperar o PR mensal, para corrigir algo urgente.
15. Como dono, quero que os PRs do Dependabot nunca sejam mesclados sozinhos, para que nada mude na VPS sem minha aprovação.
16. Como dono, quero que o `docs.sh` acuse se a configuração do Dependabot sumir ou deixar de cobrir um tipo de arquivo de imagem, para eu não descobrir só meses depois.
17. Como dono, quero saber pelo README onde ver se o Dependabot leu a configuração sem erro, já que não há validador local.
18. Como dono, quero avisos só pelo GitHub, sem e-mail, como já é nos sites.

## Implementation Decisions

- **Ferramenta: Dependabot.** É o mesmo dos sites e não exige app novo. O Renovate foi descartado: leria as tags do `.env` dos testes, mas obrigaria a manter duas ferramentas.
- **Arquivo de configuração.** Cada repositório ganha a própria configuração do Dependabot, com comentários em pt-BR, como a do bbcontainer.
- **Ecossistemas:**
  - `docker-compose`: o compose principal de cada repositório e, na borda, o compose do exemplo whoami.
  - `docker`: na pilha do PC, o Dockerfile do túnel.
- **Agenda e agrupamento.** Verificação mensal. Um grupo por ecossistema, de modo que tudo venha num PR só, e `open-pull-requests-limit` acima de 0. No bbcontainer o limite é 0 de propósito; aqui é o contrário.
- **Espera de 14 dias.** `cooldown` com `default-days: 14`. Antes de fixar a configuração, confirmar na documentação atual que o cooldown vale para os ecossistemas `docker` e `docker-compose`. Ele não se aplica às atualizações de segurança, que não existem para tag de imagem de qualquer forma.
- **BusyBox:** uma regra `ignore` que bloqueia as tags `X.Y.0`. A sintaxe de versão do ecossistema Docker precisa ser conferida na documentação. Se não der para expressar a regra, ignorar só as atualizações `semver-minor` do BusyBox e documentar que o salto de linha estável é feito à mão.
- **Tags dos testes, primeira opção.** Hoje `IMAGEM_NGINX` e `IMAGEM_LOKI` estão no `smoke.env` da pilha do PC, e o Dependabot não lê `.env`. Elas passam a ser tags literais (`image:`) num compose de teste que o Dependabot leia, e a configuração aponta o diretório desse compose. O ticket precisa confirmar que o Dependabot reconhece um compose fora da raiz, pelo nome e pela pasta. Se não reconhecer, vale a opção seguinte.
- **Tags dos testes, segunda opção.** As tags ficam onde estão, e o `docs.sh` da pilha do PC confere que `IMAGEM_LOKI` é a versão do Loki anotada no README. Esta é a única fonte da versão da borda que o repositório tem. O README da borda passa a dizer, no roteiro de versão, para atualizar as duas ao aprovar um PR do Loki.
- **Loki nos dois repositórios.** Cada repositório recebe o próprio PR, sem teste que leia o outro repositório. A mesma espera de 14 dias faz os dois proporem a mesma versão. O README manda aprovar juntos.
- **READMEs.** A seção de versões de cada repositório passa a começar pelo PR do Dependabot:
  - ler as notas;
  - rodar o smoke (na pilha do PC, parar a pilha real antes, por causa das portas 9090 e 3000; o Alpine do túnel não passa pelo smoke, então rodar o `docker compose build tunel` já descrito);
  - aprovar;
  - aplicar (VPS: `git pull` e `up -d`; PC: `pull`, `build` e `up -d`).

  O roteiro à mão continua documentado. A regra "cada tag aparece em um único arquivo" é atualizada se as tags do smoke mudarem de lugar.
- **Onde conferir a configuração.** Sem validador local, o README aponta *Insights → Dependency graph → Dependabot*, onde o GitHub mostra o resultado da última leitura e os erros.
- **Sem auto-merge.** Nada de workflow ou regra que mescle PR do Dependabot.
- **Avisos.** Só pelo GitHub. Desligar o e-mail é configuração da conta do dono, não do repositório.

## Testing Decisions

- Um bom teste olha só o comportamento visível: o arquivo existe, cobre os arquivos de imagem e o README explica o fluxo. Não confere a formatação do YAML.
- Seam 1: o `testes/docs.sh` de cada repositório. Ele confere três coisas:
  - a configuração do Dependabot existe;
  - ela cobre os ecossistemas e diretórios que têm imagem;
  - o README tem o roteiro de revisão de PR, inclusive a nota de aprovar o Loki junto.
- Seam 2: se as tags do smoke continuarem no `.env`, o mesmo `docs.sh` da pilha do PC confere que a tag do Loki falso é a anotada no README.
- O YAML é validado localmente com uma leitura simples (Python ou `yq` via Docker). O resultado real é conferido no GitHub depois do merge, como passo manual do checklist.
- O smoke dos dois repositórios roda uma vez no fim, sem mudança de comportamento. Se as tags do smoke mudarem de lugar, o smoke da pilha do PC tem de continuar passando com as mesmas imagens.
- Testes que servem de modelo:
  - as verificações `tem`/`nao_tem` dos dois `docs.sh`;
  - a configuração do Dependabot do bbcontainer, com comentários em pt-BR.

## Out of Scope

- Alertas de vulnerabilidade das imagens: o Dependabot não os gera para tag Docker. Varrer as imagens com Trivy, Docker Scout ou similar fica para outra spec.
- Revisões novas dos painéis da comunidade (Traefik 17346 e Node Exporter Full 1860).
- CI no GitHub para rodar o smoke nos PRs.
- Auto-merge e deploy automático na VPS (deploy pelo CI continua pendente no HANDOFF).
- Os sites, cujo Dependabot já está configurado.
- Pin por digest (`@sha256`).

## Further Notes

- Inventário de hoje:
  - **Borda:**
    - `traefik:v3.7.16`;
    - `tecnativa/docker-socket-proxy:v0.5.0`;
    - `prom/node-exporter:v1.12.1`;
    - `busybox:1.36.1-musl`, duas vezes (`wget-loki` e `disco-loki`);
    - `grafana/loki:3.7.8`;
    - `grafana/alloy:v1.20.1`;
    - `traefik/whoami:v1.12.0`, só no exemplo e no smoke.
  - **Pilha do PC:**
    - `prom/prometheus:v3.15.0`;
    - `prom/blackbox-exporter:v0.29.0`;
    - `grafana/grafana:13.2.3`;
    - `alpine:3.23.7`, no Dockerfile do túnel;
    - `nginx:1.30.6-alpine` e `grafana/loki:3.7.8`, só no smoke.

  Todas vêm do Docker Hub.
- Referência: <https://docs.github.com/en/code-security/dependabot/working-with-dependabot/dependabot-options-reference>. Lá estão os ecossistemas `docker` e `docker-compose`, o `cooldown` (`default-days`, `semver-*-days`, `include`/`exclude`, só para atualizações de versão), o `ignore` (`versions`, `update-types`) e os `groups`.
- Os dois repositórios já têm os alertas do Dependabot e as correções de segurança automáticas desligados, porque não têm pacotes. Esta spec não muda isso.
