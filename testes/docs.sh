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
nao_tem README.md 'UptimeRobot' "README sem monitor externo (pilha 100% local)"
nao_tem README.md '(nas próximas etapas)' "README sem texto de etapa futura do Grafana"
nao_tem README.md 'provisionado (esta versão)' "roteiro não marca a etapa 4 como atual"
exit $((falhas > 0))
