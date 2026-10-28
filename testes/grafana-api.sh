#!/usr/bin/env bash
# Teste isolado do grafana-api.sh (não sobe docker nem usa portas fixas:
# um servidor HTTP falso em Python escuta numa porta livre do loopback).
set -u
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
SERVIDOR_PID=""
trap '[ -n "$SERVIDOR_PID" ] && kill "$SERVIDOR_PID" 2>/dev/null; rm -rf "$TMP"' EXIT

cat >"$TMP/falso.py" <<'PY'
import base64, http.server, json, sys

LOG, PORTA = sys.argv[1], sys.argv[2]

class H(http.server.BaseHTTPRequestHandler):
    def tratar(self):
        n = int(self.headers.get("Content-Length") or 0)
        corpo = self.rfile.read(n).decode()
        auth = self.headers.get("Authorization", "")
        usuario_senha = base64.b64decode(auth[6:]).decode() if auth.startswith("Basic ") else ""
        with open(LOG, "a") as f:
            f.write(json.dumps({"metodo": self.command, "caminho": self.path,
                                "corpo": corpo, "auth": usuario_senha}) + "\n")
        if self.path.startswith("/falha"):
            codigo, resp = 409, {"message": "regra provisionada"}
        else:
            codigo, resp = 200, {"metodo": self.command, "corpo": corpo}
        dados = json.dumps(resp).encode()
        self.send_response(codigo)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(dados)))
        self.end_headers()
        self.wfile.write(dados)
    do_GET = do_POST = do_PUT = do_DELETE = tratar
    def log_message(self, *a): pass

s = http.server.HTTPServer(("127.0.0.1", 0), H)
open(PORTA, "w").write(str(s.server_port))
s.serve_forever()
PY

python3 "$TMP/falso.py" "$TMP/log" "$TMP/porta" &
SERVIDOR_PID=$!
for _ in $(seq 50); do [ -s "$TMP/porta" ] && break; sleep 0.1; done
PORTA="$(cat "$TMP/porta")"
: >"$TMP/log"

# Cópia do script numa pasta com .env próprio (o script lê o .env ao lado dele).
mkdir "$TMP/repo"
cp "$RAIZ/grafana-api.sh" "$TMP/repo/"
printf 'GRAFANA_SENHA_ADMIN=senha-do-dotenv\nPORTA_GRAFANA=%s\n' "$PORTA" >"$TMP/repo/.env"
S="$TMP/repo/grafana-api.sh"
SEGREDO="senha-do-ambiente-X"

falhas=0
confere() { # descrição esperado obtido
  if [ "$2" = "$3" ]; then echo "ok    $1"; else echo "FALHA $1 (esperado: '$2'; obtido: '$3')"; falhas=$((falhas + 1)); fi
}
ultimo() { tail -n 1 "$TMP/log" | jq -r ".$1"; }

# 1. GET usa .env (senha e porta) e devolve JSON, saída 0
saida="$("$S" GET /api/x 2>"$TMP/err")"; cod=$?
confere "GET sai com 0" 0 "$cod"
confere "GET imprime o JSON da resposta" GET "$(jq -r .metodo <<<"$saida")"
confere "GET usa admin e a senha do .env" "admin:senha-do-dotenv" "$(ultimo auth)"
confere "GET usa a porta do .env" /api/x "$(ultimo caminho)"

# 2. POST com corpo por argumento
"$S" POST /api/y '{"a":1}' >/dev/null
confere "POST com corpo em argumento" '{"a":1}' "$(ultimo corpo)"
# 3. PUT com corpo por stdin
echo '{"b":2}' | "$S" PUT /api/z >/dev/null
confere "PUT com corpo na entrada padrão" PUT "$(ultimo metodo)"
confere "PUT: corpo chegou" '{"b":2}' "$(ultimo corpo | tr -d '\n')"
# 4. DELETE
"$S" DELETE /api/w >/dev/null; cod=$?
confere "DELETE sai com 0" 0 "$cod"
confere "DELETE chegou como DELETE" DELETE "$(ultimo metodo)"

# 5. Não 2xx: erro com código e corpo
"$S" GET /falha >"$TMP/out" 2>"$TMP/err"; cod=$?
confere "não 2xx sai com erro" 1 "$cod"
grep -q 409 "$TMP/err" && grep -q 'regra provisionada' "$TMP/err"
confere "erro mostra código HTTP e corpo" 0 $?

# 6. Ambiente tem prioridade sobre .env
GRAFANA_URL="http://127.0.0.1:$PORTA" GRAFANA_SENHA_ADMIN="$SEGREDO" "$S" GET /api/env >"$TMP/out" 2>"$TMP/err"
confere "ambiente: senha do ambiente vence o .env" "admin:$SEGREDO" "$(ultimo auth)"
# porta do .env errada, mas URL do ambiente certa
printf 'GRAFANA_SENHA_ADMIN=s\nPORTA_GRAFANA=1\n' >"$TMP/repo/.env"
GRAFANA_URL="http://127.0.0.1:$PORTA" "$S" GET /api/url >/dev/null 2>&1
confere "ambiente: endereço do ambiente vence a porta do .env" /api/url "$(ultimo caminho)"

# 7. Senha nunca aparece em stdout/stderr, nem no erro
for args in "GET /api/env" "GET /falha"; do
  GRAFANA_URL="http://127.0.0.1:$PORTA" GRAFANA_SENHA_ADMIN="$SEGREDO" "$S" $args >"$TMP/out" 2>"$TMP/err"
  ! grep -q "$SEGREDO" "$TMP/out" "$TMP/err"
  confere "senha fora da saída ($args)" 0 $?
done
# senha ausente: erro claro, sem chamar a API
rm "$TMP/repo/.env"
env -u GRAFANA_SENHA_ADMIN "$S" GET /api/x >/dev/null 2>"$TMP/err"; cod=$?
confere "sem senha: sai com erro" 1 "$cod"

[ "$falhas" -eq 0 ] && echo "grafana-api.sh: tudo ok" || echo "grafana-api.sh: $falhas falha(s)"
exit "$falhas"
