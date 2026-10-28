# Hook de pre-commit no homelab

Status: ready-for-agent

## Problem Statement

O homelab-monitoring não tem nenhuma verificação automática. Não há hook de pre-commit nem CI. O `docs.sh` é rápido e não sobe contêineres, mas só roda quando alguém lembra.

Documentação desatualizada ou uma checagem quebrada chega ao commit sem aviso.

## Solution

O repositório ganha um hook de pre-commit versionado que roda o `docs.sh`. Se o `docs.sh` falhar, o commit é recusado e a saída mostra o que falhou.

O hook é ativado uma vez por clone, com um comando que o README explica. A mesma ideia vale para o traefik-default, em spec própria naquele repositório.

## User Stories

1. Como dono, quero que o commit seja recusado quando o `docs.sh` falhar, para não publicar documentação desatualizada.
2. Como dono, quero ver no terminal quais checagens falharam quando o commit for recusado.
3. Como dono, quero ativar o hook com um único comando, descrito no README.
4. Como dono, quero que o hook fique versionado no repositório, para valer igual em qualquer clone.
5. Como dono, quero que o hook seja rápido (segundos) e nunca suba contêineres.
6. Como dono, quero poder pular o hook numa emergência, com o `--no-verify` padrão do git.
7. Como agente, quero que o README diga que o hook existe e o que ele roda, para eu rodar o mesmo antes de commitar.

## Implementation Decisions

- O hook fica numa pasta versionada de hooks e é ativado com `git config core.hooksPath` apontando para ela.
- O hook roda só o `docs.sh`. O smoke fica de fora: sobe contêineres e leva cerca de um minuto.
- O hook roda a partir da raiz do repositório, qualquer que seja a pasta de onde o commit foi feito.
- Sem CI: o homelab não tem workflows, e esta spec não cria.

## Testing Decisions

- Um bom teste olha o comportamento visível: um commit com o `docs.sh` falhando é recusado, e um commit com o `docs.sh` passando é aceito.
- **Seam: `docs.sh`.** Confere que o hook existe, é executável, chama o `docs.sh` e que o README explica a ativação.
- Teste manual: num clone temporário com o hook ativado, quebrar de propósito uma frase que o `docs.sh` confere, tentar commitar e ver a recusa. Desfazer e ver o commit passar.
- Modelo: o hook do conan-torres, que já roda checagens no pre-commit.

## Out of Scope

- CI em GitHub Actions.
- Rodar o smoke no hook.
- O hook do traefik-default (spec própria lá).

## Further Notes

- Origem: retro da sessão do deploy pelo cron (2026-10-28), candidato 2.
