# Hook de pre-commit com sintaxe, shellcheck e testes isolados

Status: ready-for-agent

## Problem Statement

O repositório não tem hook nem CI. Os scripts já trazem diretivas `# shellcheck source=`, mas nada roda o shellcheck. O `testes/grafana-api.sh`, isolado e sem docker, só roda quando alguém lembra: na revisão de 2026-10-28 ninguém o chamava.

A spec `03-hook-pre-commit` cobre só o `docs.sh`.

## Solution

O hook de pre-commit versionado (spec `03-hook-pre-commit`) passa a rodar, nesta ordem e em segundos:

1. `bash -n` nos scripts shell do repositório;
2. `shellcheck` nesses scripts, quando o programa estiver instalado;
3. `docs.sh`;
4. os testes isolados (`testes/grafana-api.sh`), que não usam docker nem portas fixas.

Falhou uma etapa, o commit é recusado e a saída diz qual.

## User Stories

1. Como dono, quero que um erro de sintaxe num script seja barrado no commit.
2. Como dono, quero que o shellcheck rode no commit, já que os scripts têm diretivas dele.
3. Como dono, quero que o teste isolado do ajudante da API rode a cada commit.
4. Como agente, quero que o README liste o que o hook roda, para eu rodar o mesmo antes de commitar.
5. Como dono, quero que o hook continue rápido e sem docker, e possa ser pulado com `--no-verify`.

## Implementation Decisions

- Estende o hook criado pela spec `03-hook-pre-commit`; não cria um segundo hook.
- Sem `shellcheck` instalado, o hook avisa que pulou essa etapa e segue. Não falha por falta do programa.
- A lista de testes isolados fica num ponto só, para o README e o hook lerem dela.
- O smoke continua fora do hook.

## Testing Decisions

- **Seam: `docs.sh`.** Confere que o README lista as 4 etapas.
- Teste manual em clone temporário com o hook ativo: introduzir um erro de sintaxe e ver a recusa; quebrar o `testes/grafana-api.sh` e ver a recusa; desfazer e ver o commit passar.
- Modelo: o hook e o padrão ok/FALHA do `docs.sh`.

## Out of Scope

- CI em GitHub Actions.
- Rodar o smoke no hook.
- O hook do traefik-default.

## Further Notes

- Origem: retro da sessão `grafana-api` (2026-10-28), item 1.
- Bloqueada pela spec `03-hook-pre-commit`.
- Pode precisar corrigir avisos que o shellcheck já encontre nos scripts atuais; isso entra nesta spec, sem mudar comportamento.
