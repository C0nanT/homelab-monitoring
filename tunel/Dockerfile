# SSH tunnel image (autossh) to the VPS loopback.
# Alpine with a PINNED tag; autossh and openssh-client come from its packages.
# To update: change the tag here and run "docker compose up -d --build"
# (see "Pinning and updating versions" in the README).
FROM alpine:3.24.2
RUN apk add --no-cache autossh openssh-client
COPY iniciar.sh /iniciar.sh
ENTRYPOINT ["/bin/sh", "/iniciar.sh"]
