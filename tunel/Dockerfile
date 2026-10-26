# Imagem do túnel SSH (autossh) até o loopback da VPS.
# Alpine com tag FIXA; autossh e openssh-client vêm dos pacotes dela.
# Para atualizar: troque a tag aqui e rode "docker compose up -d --build"
# (veja "Fixar e atualizar as versões" no README).
FROM alpine:3.23.7
RUN apk add --no-cache autossh openssh-client
COPY iniciar.sh /iniciar.sh
ENTRYPOINT ["/bin/sh", "/iniciar.sh"]
