#!/usr/bin/env bash
# Verificação isolada da documentação (não sobe nada, não usa portas).
# Confere os pontos exigidos do README.
set -u
cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 1
falhas=0
tem() { # arquivo padrão descrição
  if grep -qF -- "$2" "$1" 2>/dev/null; then
    echo "ok    $3"
  else
    echo "FALHA $3 ($1: $2)"
    falhas=$((falhas + 1))
  fi
}
nao_tem() { # arquivo padrão descrição
  if grep -qF -- "$2" "$1" 2>/dev/null; then
    echo "FALHA $3 ($1 ainda tem: $2)"
    falhas=$((falhas + 1))
  else
    echo "ok    $3"
  fi
}
tem_re() { # arquivo regex-estendida descrição
  if grep -qE -- "$2" "$1" 2>/dev/null; then
    echo "ok    $3"
  else
    echo "FALHA $3 ($1: /$2/)"
    falhas=$((falhas + 1))
  fi
}
tem README.md 'Arquitetura' "README explica a arquitetura"
tem README.md 'túnel' "README cita o túnel"
tem README.md 'loopback' "README cita o loopback da VPS"
tem README.md 'só vale com o PC ligado' "README avisa que o uptime só vale com o PC ligado"
tem README.md 'Fixar e atualizar as versões' "README tem roteiro de atualização"
tem README.md 'Adicionar um site' "README explica como adicionar um site"
tem README.md 'testes/smoke.sh' "README explica o smoke test"
tem README.md 'Roteiro' "README tem o roteiro de versões"
tem .env.example 'PORTA_PROMETHEUS' ".env.example documenta as variáveis"
tem .gitignore '.env' ".gitignore ignora .env"
tem .gitignore 'chaves/*' ".gitignore ignora a pasta de chaves"
tem README.md 'Túnel até a VPS' "README tem a seção do túnel"
tem README.md 'ssh-keygen -t ed25519' "README: gerar a chave dedicada"
tem README.md 'ssh-keyscan' "README: pegar o known_hosts da VPS"
tem README.md 'ssh-keygen -lf' "README: conferir a impressão digital da VPS"
tem README.md 'TUNEL_HOST' "README: preencher o .env do túnel"
tem README.md 'Monitoramento a partir de outra máquina' "README aponta o lado da VPS no traefik-default"
tem README.md 'tunel/Dockerfile' "README: roteiro de versão cobre a imagem do túnel"
tem .env.example 'TUNEL_HOST' ".env.example documenta o host do túnel"
tem .env.example 'TUNEL_USUARIO' ".env.example documenta o usuário do túnel"
tem README.md '## Grafana' "README tem a seção do Grafana"
tem README.md 'GRAFANA_SENHA_ADMIN' "README: senha do admin vem do .env"
tem README.md 'grafana/dashboards' "README: onde ficam os JSON dos painéis"
tem README.md 'grafana/provisioning/alerting' "README: pasta onde entram os alertas"
tem README.md 'Atualizar um painel' "README: como atualizar um painel da comunidade"
tem .env.example 'GRAFANA_SENHA_ADMIN' ".env.example documenta a senha do Grafana"
tem README.md '## Alertas no Telegram' "README tem a seção de alertas"
tem README.md '@BotFather' "README: criar o bot no BotFather"
tem README.md 'getUpdates' "README: achar o chat ID"
tem README.md 'TELEGRAM_BOT_TOKEN' "README: preencher o token no .env"
tem README.md 'alerta de teste' "README: mandar um alerta de teste"
tem README.md 'mensagem.yml' "README: onde fica o texto das mensagens"
tem README.md '`limites`' "README: limites ajustáveis num lugar só"
tem .env.example 'TELEGRAM_BOT_TOKEN' ".env.example documenta o token do bot"
tem .env.example 'TELEGRAM_CHAT_ID' ".env.example documenta o chat ID"
tem .env.example 'regras.yml' ".env.example aponta onde ficam os limites"
tem README.md '## Colocar no ar' "README tem a seção de colocar no ar"
tem README.md 'merge do `feature/homelab-monitoring`' "README: publicar a borda no GitHub antes do git pull"
tem README.md 'cd /opt/traefik && git pull' "README: atualizar a borda na VPS"
tem README.md 'curl -s http://127.0.0.1:9100/metrics' "README: node exporter responde no loopback da VPS"
tem README.md 'curl -m 5 http://IP_DA_VPS:9100/metrics' "README: porta 9100 não aparece de fora"
tem README.md '## Checklist manual' "README tem o checklist manual"
tem README.md 'suspender o PC' "checklist: túnel volta depois de suspender o PC"
tem README.md 'docker compose restart traefik' "checklist: coleta volta depois de reiniciar o Traefik"
tem README.md '127.0.0.1:8080' "checklist: chave do metricas recusa encaminhar para 8080"
tem README.md 'permitopen="127.0.0.1:3100"' "README: authorized_keys do metricas libera a 3100"
tem README.md 'tunel:3100' "README: o túnel encaminha o Loki para tunel:3100"
tem README.md 'grafana/provisioning/datasources/loki.yml' "README: onde fica a fonte de dados Loki"
tem README.md 'loki-falso' "README: smoke tem Loki falso atrás do túnel"
tem README.md '## Logs' "README tem a seção de logs"
tem README.md 'grafana/dashboards/logs.json' "README: onde fica o painel Logs"
tem README.md 'Explore' "README: consultas livres no Explore"
tem README.md '| json' "README: exemplos de LogQL"
tem README.md '**Logs** (`logs.json`' "README: tabela de painéis lista o Logs"
tem README.md '(-www)?@.+' "README: painel Logs inclui o router do www"
tem README.md 'duração em ms' "README: duração do acesso em ms"
tem README.md 'crases na consulta' "README: busca vai entre crases"
nao_tem README.md 'duração em ns' "README sem a duração em ns (agora em ms)"
tem README.md 'socket-proxy' "README: borda sem o ruído do socket-proxy"
tem testes/verificacoes/07-painel-logs.sh 'conan-torres-www' "smoke confere o router do www no painel Logs"
tem testes/verificacoes/07-painel-logs.sh 'homelab-logs' "smoke confere o painel Logs"
tem tunel/iniciar.sh '127.0.0.1:3100' "túnel encaminha a 3100"
tem docker-compose.yml 'nc -z 127.0.0.1 3100' "healthcheck do túnel confere a 3100"
tem grafana/provisioning/datasources/loki.yml 'uid: loki' "fonte de dados Loki provisionada com uid fixo"
tem grafana/provisioning/datasources/loki.yml 'http://tunel:3100' "fonte de dados Loki aponta para o túnel"
nao_tem README.md 'UptimeRobot' "README sem monitor externo (pilha 100% local)"
nao_tem README.md '(nas próximas etapas)' "README sem texto de etapa futura do Grafana"
nao_tem README.md 'provisionado (esta versão)' "roteiro não marca a etapa 4 como atual"
tem README.md 'loki_dados_bytes' "README: painel Logs mostra o disco do Loki"
tem testes/verificacoes/07-painel-logs.sh 'Disco do Loki' "smoke confere o disco do Loki no painel Logs"
# Deploy pelo cron: linha "Deploy (cron)" no painel Logs e dois alertas.
tem README.md 'Deploy (cron)' "README: linha Deploy (cron) do painel Logs"
tem README.md 'deploy_falhou' "README: série do estado de cada site"
tem README.md 'deploy_rodada_timestamp_seconds' "README: série da hora da última rodada"
tem README.md 'job="atualizar-apps"' "README: rótulo do log do cron no Loki"
tem README.md '| Deploy falhou (VPS) |' "README: tabela lista o alerta Deploy falhou (VPS)"
tem README.md '| Cron de deploy parado |' "README: tabela lista o alerta Cron de deploy parado"
tem README.md 'deploy_parado_min' "README: limite do cron parado fica em limites"
tem grafana/provisioning/alerting/regras.yml 'title: Deploy falhou (VPS)' "regras.yml tem o alerta Deploy falhou (VPS)"
tem grafana/provisioning/alerting/regras.yml 'title: Cron de deploy parado' "regras.yml tem o alerta Cron de deploy parado"
tem grafana/provisioning/alerting/regras.yml 'deploy_parado_min: &limite_deploy_parado_min' "regras.yml: limite do cron parado no bloco limites"
nao_tem grafana/provisioning/alerting/regras.yml 'há mais de 30 minutos' "regras.yml: texto do cron parado não repete o limite (só deploy_parado_min)"
nao_tem grafana/dashboards/logs.json 'mais de 30 min' "logs.json: descrição não repete o limite do cron parado"
nao_tem README.md 'há mais de **30 min**' "README: tabela de alertas não repete o limite do cron parado"
tem grafana/provisioning/alerting/regras.yml '$labels.app' "alerta de deploy cita o app na mensagem"
tem testes/verificacoes/05-alertas.sh 'Deploy falhou (VPS)' "smoke confere o alerta Deploy falhou (VPS)"
tem testes/verificacoes/05-alertas.sh 'Cron de deploy parado' "smoke confere o alerta Cron de deploy parado"
tem testes/verificacoes/07-painel-logs.sh 'Deploy (cron)' "smoke confere a linha Deploy (cron) do painel Logs"
tem testes/fixtures/tunel-falso/gerar-metricas.sh 'deploy_rodada_timestamp_seconds' "túnel falso publica as séries do deploy"
tem_re .github/dependabot.yml '^  - package-ecosystem: "?docker-compose"?$' "Dependabot cobre o compose principal"
tem_re .github/dependabot.yml '^  - package-ecosystem: "?docker"?$' "Dependabot cobre o Dockerfile do túnel"
tem_re .github/dependabot.yml '^    directory: "?/tunel"?$' "Dependabot aponta para a pasta do Dockerfile do túnel"
tem .github/dependabot.yml 'interval: monthly' "Dependabot roda uma vez por mês"
tem .github/dependabot.yml 'default-days: 14' "Dependabot só propõe versões com 14 dias de publicadas"
tem .github/dependabot.yml 'groups:' "Dependabot agrupa as imagens em um PR por ecossistema"
nao_tem .github/dependabot.yml 'open-pull-requests-limit: 0' "Dependabot não está desligado"
tem README.md 'PR do Dependabot' "README: roteiro começa pelo PR do Dependabot"
tem README.md 'docker compose build tunel' "README: PR do Alpine passa pelo build do túnel"
tem README.md 'O PR do Loki chega só no `traefik-default`. Ao aprová-lo, atualize aqui' "README: PR do Loki chega só na borda e manda atualizar aqui junto"
tem README.md 'Dependency graph' "README: onde conferir se o Dependabot leu a configuração"
# Tags que só o smoke usa (Dependabot não as lê): o Loki falso acompanha a borda.
loki_readme=$(grep -oE 'Loki da borda: `grafana/loki:[0-9][0-9.]*`' README.md | head -1 | grep -oE '[0-9][0-9.]*`$' | tr -d '`')
loki_smoke=$(grep -E '^IMAGEM_LOKI=' testes/smoke.env | head -1 | sed -E 's/.*grafana\/loki://')
igual() { # esperado obtido descrição
  if [ -n "$2" ] && [ "$1" = "$2" ]; then
    echo "ok    $3 ($2)"
  else
    echo "FALHA $3 (README: ${1:-sem nota}; smoke.env: ${2:-?})"
    falhas=$((falhas + 1))
  fi
}
igual "$loki_readme" "$loki_smoke" "Loki falso do smoke igual ao Loki da borda anotado no README"
tem README.md 'não lê o `.env`' "README: motivo de nginx e Loki falso ficarem fora do Dependabot"
tem README.md 'confere a tag do Loki falso' "README: docs.sh confere o Loki falso contra a nota da borda"
nao_tem README.md 'O PR do Loki chega nos dois repositórios' "README não promete PR do Loki neste repositório"
if [ -n "$(ls .github/workflows 2>/dev/null)" ]; then echo "FALHA .github/workflows não deve existir (sem auto-merge)"; falhas=$((falhas + 1)); else echo "ok    sem workflow de auto-merge"; fi
# Checklist da falha forçada: a referência fica na seção dos alertas e aponta o checklist da borda.
tem README.md '../traefik-default#checklist-manual-da-falha-forçada' "README: aponta o checklist da falha forçada na borda"
tem README.md 'Para ver os dois alertas de deploy dispararem de verdade' "README: referência ao checklist da falha forçada, junto dos alertas"
# Ajudante da API do Grafana: exemplos curtos na seção do Grafana.
tem README.md '### Consultar a API do Grafana' "README: seção do ajudante da API do Grafana"
tem README.md './grafana-api.sh GET /api/v1/provisioning/alert-rules | jq' "README: exemplo lista as regras de alerta"
tem README.md './grafana-api.sh GET /api/prometheus/grafana/api/v1/rules | jq' "README: exemplo mostra o estado dos alertas com jq"
tem README.md './grafana-api.sh GET /api/datasources/uid/loki/health | jq' "README: exemplo testa a fonte de dados Loki"
# Pegadinha do provisioning: regra provisionada só sai com deleteRules (seção de alertas).
tem README.md '### Tirar uma regra' "README: seção para tirar uma regra dos alertas"
tem README.md 'não a apaga do Grafana' "README: tirar a regra do arquivo não a apaga do Grafana"
tem README.md 'deleteRules:' "README: bloco deleteRules de exemplo"
tem README.md 'Depois do restart, tire o `deleteRules` do arquivo' "README: remover o deleteRules depois de aplicar"
# Smoke em portas próprias: convive com a pilha real.
tem README.md '127.0.0.1:19090' "README: smoke usa a porta 19090 do Prometheus"
tem README.md '127.0.0.1:13000' "README: smoke usa a porta 13000 do Grafana"
tem README.md 'com a pilha real de pé' "README: smoke convive com a pilha real"
nao_tem README.md 'Pare a pilha real' "README: atualização de imagens não manda parar a pilha real"
nao_tem README.md 'não rode com a pilha' "README: smoke não proíbe rodar com a pilha real"
nao_tem testes/smoke.sh 'Não rode com a' "smoke.sh: aviso do topo não manda parar a pilha real"
tem testes/smoke.sh 'PORTA_PROMETHEUS' "smoke.sh: aviso do topo diz como trocar as portas"
# Smoke: o ambiente manda no smoke.env, que só dá os padrões.
tem README.md 'o ambiente tem prioridade sobre o `testes/smoke.env`' "README: ambiente tem prioridade sobre o smoke.env"
tem testes/smoke.sh 'o ambiente tem prioridade sobre o smoke.env' "smoke.sh: cabeçalho diz que o ambiente tem prioridade"
# Hook de pre-commit versionado: roda o docs.sh e é ativado por core.hooksPath.
if [ -x .githooks/pre-commit ]; then echo "ok    hook .githooks/pre-commit existe e é executável"; else echo "FALHA .githooks/pre-commit não existe ou não é executável"; falhas=$((falhas + 1)); fi
tem_re .githooks/pre-commit '^if ! testes/docs\.sh' "hook chama o docs.sh"
nao_tem .githooks/pre-commit 'smoke.sh' "hook não roda o smoke"
tem README.md 'git config core.hooksPath .githooks' "README: comando que ativa o hook"
tem README.md '--no-verify' "README: como pular o hook numa emergência"
tem README.md 'Hook de pre-commit' "README tem a seção do hook de pre-commit"
# Hook estendido: bash -n, shellcheck, docs.sh e os testes isolados (lista em testes/isolados.txt).
tem_re .githooks/pre-commit '^  bash -n "\$s"' "hook confere a sintaxe com bash -n"
tem_re .githooks/pre-commit '^  shellcheck -x ' "hook roda o shellcheck"
tem_re .githooks/pre-commit '^done <testes/isolados\.txt' "hook lê a lista de testes isolados"
tem README.md '`bash -n`' "README: etapa 1 do hook (bash -n)"
tem README.md '`shellcheck`' "README: etapa 2 do hook (shellcheck)"
tem README.md 'testes/isolados.txt' "README: onde fica a lista de testes isolados"
if [ -f testes/isolados.txt ]; then
  while IFS= read -r teste; do
    [ -n "$teste" ] || continue
    if [ -x "$teste" ]; then echo "ok    teste isolado $teste existe e é executável"; else echo "FALHA teste isolado $teste não existe ou não é executável"; falhas=$((falhas + 1)); fi
    tem README.md "$teste" "README lista o teste isolado $teste"
  done <testes/isolados.txt
else
  echo "FALHA testes/isolados.txt não existe"; falhas=$((falhas + 1))
fi
exit $((falhas > 0))
