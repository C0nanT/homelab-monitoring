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
tem .github/dependabot.yml 'package-ecosystem: docker-compose' "Dependabot cobre o compose principal"
tem .github/dependabot.yml 'package-ecosystem: docker' "Dependabot cobre o Dockerfile do túnel"
tem .github/dependabot.yml 'directory: /tunel' "Dependabot aponta para a pasta do Dockerfile do túnel"
tem .github/dependabot.yml 'interval: monthly' "Dependabot roda uma vez por mês"
tem .github/dependabot.yml 'default-days: 14' "Dependabot só propõe versões com 14 dias de publicadas"
tem .github/dependabot.yml 'groups:' "Dependabot agrupa as imagens em um PR por ecossistema"
nao_tem .github/dependabot.yml 'open-pull-requests-limit: 0' "Dependabot não está desligado"
tem README.md 'PR do Dependabot' "README: roteiro começa pelo PR do Dependabot"
tem README.md 'docker compose build tunel' "README: PR do Alpine passa pelo build do túnel"
tem README.md 'PR do Loki' "README: PR do Loki chega nos dois repositórios"
tem README.md 'Dependency graph' "README: onde conferir se o Dependabot leu a configuração"
# Tags que só o smoke usa (Dependabot não as lê): o Loki falso acompanha a borda.
loki_readme=$(grep -oE 'Loki da borda: `grafana/loki:[0-9][0-9.]*`' README.md | head -1 | grep -oE '[0-9][0-9.]*`$' | tr -d '`')
loki_smoke=$(grep -E '^IMAGEM_LOKI=' testes/smoke.env | head -1 | sed -E 's/.*grafana\/loki://')
if [ -n "$loki_readme" ] && [ "$loki_readme" = "$loki_smoke" ]; then
  echo "ok    Loki falso do smoke ($loki_smoke) igual ao Loki da borda anotado no README"
else
  echo "FALHA Loki falso do smoke (${loki_smoke:-?}) difere do Loki da borda anotado no README (${loki_readme:-sem nota})"
  falhas=$((falhas + 1))
fi
tem README.md 'não lê o `.env`' "README: motivo de nginx e Loki falso ficarem fora do Dependabot"
tem README.md 'confere a tag do Loki falso' "README: docs.sh confere o Loki falso contra a nota da borda"
nao_tem README.md 'O PR do Loki chega nos dois repositórios' "README não promete PR do Loki neste repositório"
if [ -n "$(ls .github/workflows 2>/dev/null)" ]; then echo "FALHA .github/workflows não deve existir (sem auto-merge)"; falhas=$((falhas + 1)); else echo "ok    sem workflow de auto-merge"; fi
exit $((falhas > 0))
