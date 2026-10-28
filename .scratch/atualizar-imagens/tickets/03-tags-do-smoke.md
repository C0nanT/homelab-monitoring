# 03: Tags do smoke vigiadas (nginx e Loki falso)

> **Difficulty:** Standard: **suggested model:** Sonnet (Claude Code) / Sonnet (Cursor). Suggestion only, use whatever model you have to hand.

**Spec:** ../SPEC.md

**What to build:** As imagens que só o smoke da pilha do PC usa (o nginx dos sites falsos e o Loki falso) deixam de ficar invisíveis. Primeira opção: elas viram tags literais num compose de teste que o Dependabot lê, e entram no PR mensal do ticket 02. Se o Dependabot não reconhecer esse compose (pelo nome ou pela pasta), segunda opção: as tags ficam onde estão e o `docs.sh` falha quando a tag do Loki falso diverge da versão do Loki anotada no README. Nos dois casos, o README da borda passa a lembrar de manter o Loki falso igual ao da borda ao aprovar um PR do Loki.

**Seams:**
- Seam 1 do spec: o `testes/docs.sh` do `homelab-monitoring` (cobertura do compose de teste, primeira opção)
- Seam 2 do spec: o mesmo `docs.sh` conferindo a tag do Loki falso contra o README (segunda opção)

**Blocked by:** 02 (Dependabot das imagens na pilha do PC)

Status: ready-for-agent

- [x] Decidido, com base na documentação do Dependabot sobre nomes e pastas de compose reconhecidos, entre a primeira e a segunda opção; a decisão e o motivo ficam registrados no README
- [ ] Primeira opção: nginx (com o sufixo `-alpine`) e Loki falso como `image:` literais num compose de teste, a configuração do Dependabot cobre esse diretório, e o `docs.sh` confere essa cobertura
- [x] Segunda opção: `docs.sh` falha quando a tag do Loki falso difere da versão do Loki anotada no README
- [x] A regra "cada tag aparece em um único arquivo" do README continua verdadeira (atualizada se as tags mudarem de lugar)
- [x] README do `traefik-default`: o roteiro de versão manda atualizar o Loki falso do homelab junto ao aprovar um PR do Loki
- [x] O smoke da pilha do PC continua passando com as mesmas imagens de antes
- [x] `testes/docs.sh` dos dois repositórios passa
