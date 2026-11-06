#!/usr/bin/env bash
# Testes do cop com um "copilot" falso que só grava os argumentos. Não gasta nada.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
COP="$ROOT/plugins/copilot-delegate/bin/cop"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
mkdir -p "$T/bin" "$T/home/agents" "$T/proj"
cat >"$T/bin/copilot" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$@" >"$FAKE_ARGS"
pwd >"$FAKE_ARGS.pwd"
[ -n "${FAKE_SLEEP:-}" ] && sleep "$FAKE_SLEEP"
[ -n "${FAKE_BIG:-}" ] && head -c 9000 /dev/zero | tr '\0' 'x'
[ -n "${FAKE_WRITE:-}" ] && echo "novo" >"$FAKE_WRITE"
echo "RESULTADO: ok"
exit "${FAKE_EXIT:-0}"
EOF
chmod +x "$T/bin/copilot"
export PATH="$T/bin:$PATH" FAKE_ARGS="$T/args" COP_LOG_DIR="$T/logs" COPILOT_HOME="$T/home"
unset COP_ACTIVE COP_MODEL COP_EFFORT

PASS=0 FAIL=0
check() { if eval "$2"; then PASS=$((PASS+1)); echo "ok   $1"; else FAIL=$((FAIL+1)); echo "FAIL $1"; fi; }
has() { grep -qxF -- "$1" "$T/args"; }

out=$("$COP" "onde X é usado?"); st=$?
check "leitura: status 0" '[ $st = 0 ]'
check "leitura: modelo padrão gpt-6-luna" 'has gpt-6-luna'
check "leitura: bloqueia escrita" 'has "--deny-tool=write"'
check "leitura: não libera write" '! has "--allow-tool=write"'
check "leitura: prefixo MODO LEITURA" 'grep -q "MODO LEITURA" "$T/args"'
check "sempre: -s e --no-ask-user" 'has -s && has --no-ask-user'
check "sempre: bloqueia git push" 'has "--deny-tool=shell(git push:*)"'
check "sempre: bloqueia recursão" 'has "--deny-tool=shell(cop:*)" && has "--deny-tool=shell(copilot:*)"'
check "sempre: sem allow-all" '! grep -qE -- "--allow-all|--yolo" "$T/args"'
check "sempre: desliga MCP embutido" 'has --disable-builtin-mcps'
check "sem agente instalado: contrato no prompt" 'grep -q "resumo de até 15 linhas" "$T/args" && ! has --agent'
check "saída tem linha [cop]" 'echo "$out" | grep -q "status=0"'

touch "$T/home/agents/cop-worker.agent.md"
"$COP" -w -m claude-haiku-4.5 -e medium -C "$T/proj" "crie testes" >/dev/null
check "escrita: libera write e flutter" 'has "--allow-tool=write" && has "--allow-tool=shell(flutter:*)"'
check "escrita: -m e -e" 'has claude-haiku-4.5 && has medium'
check "escrita: usa --agent cop-worker" 'has --agent && has cop-worker'
check "escrita: roda em -C" '[ "$(cat "$T/args.pwd")" = "$(cd "$T/proj" && pwd -P)" ] || [ "$(cat "$T/args.pwd")" = "$T/proj" ]'

COP_EXTRA_ALLOW="shell(make:*) shell(./gradlew:*)" "$COP" -w "x" >/dev/null
check "COP_EXTRA_ALLOW" 'has "--allow-tool=shell(./gradlew:*)"'
COP_EFFORT="" "$COP" "x" >/dev/null
check "COP_EFFORT vazio omite --reasoning-effort" '! has --reasoning-effort'

echo "tarefa via stdin" | "$COP" >/dev/null
check "stdin" 'grep -q "tarefa via stdin" "$T/args"'

FAKE_EXIT=7 "$COP" "x" >/dev/null; st=$?
check "repassa código de saída" '[ $st = 7 ]'

out=$(FAKE_BIG=1 COP_MAX_CHARS=500 "$COP" "x");
check "corta saída longa" '[ ${#out} -lt 900 ] && echo "$out" | grep -q "mostrando os últimos 500"'

FAKE_SLEEP=5 "$COP" -t 1 "x" >/dev/null; st=$?
check "timeout devolve 124" '[ $st = 124 ]'

COP_ACTIVE=1 "$COP" "x" >/dev/null 2>&1; st=$?
check "recursão bloqueada (3)" '[ $st = 3 ]'

"$COP" >/dev/null 2>&1 </dev/null; st=$?
check "sem tarefa = uso (2)" '[ $st = 2 ]'
"$COP" -z x >/dev/null 2>&1; st=$?
check "opção inválida = 2" '[ $st = 2 ]'


# ---------- sessão (-r) ----------
"$COP" -C "$T/proj" "primeira" >/dev/null
check "nova sessão usa --session-id" 'has --session-id && ! has --resume'
SID=$(grep -A1 -- '^--session-id$' "$T/args" | tail -1)
"$COP" -r last "corrija o erro" >/dev/null
check "-r last usa --resume com a mesma sessão" 'has --resume && has "$SID"'
check "-r herda o diretório do job" '[ "$(cat "$T/args.pwd")" = "$(cd "$T/proj" && pwd -P)" ] || [ "$(cat "$T/args.pwd")" = "$T/proj" ]'
check "-r marca CONTINUAÇÃO e não reenvia --agent" 'grep -q CONTINUAÇÃO "$T/args" && ! has --agent'
"$COP" -r naoexiste "x" >/dev/null 2>&1; st=$?
check "-r job inexistente = 4" '[ $st = 4 ]'

# ---------- papéis (-R) ----------
"$COP" -R reviewer "revise" >/dev/null 2>&1; st=$?
check "reviewer sem agente instalado = 2" '[ $st = 2 ]'
touch "$T/home/agents/cop-reviewer.agent.md" "$T/home/agents/cop-tester.agent.md"
"$COP" -w -R reviewer "revise" >/dev/null
check "reviewer força leitura" 'has "--deny-tool=write" && ! has "--allow-tool=write" && has cop-reviewer'
"$COP" -R tester "teste o cubit" >/dev/null
check "tester escreve só testes" 'has "--allow-tool=write(test/**)" && ! has "--allow-tool=write" && has cop-tester'
check "tester pode rodar flutter" 'has "--allow-tool=shell(flutter:*)"'
"$COP" -R chefe "x" >/dev/null 2>&1; st=$?
check "papel inválido = 2" '[ $st = 2 ]'

# ---------- worktree (-W) ----------
R="$T/repo"; mkdir -p "$R"
git -C "$R" init -q && git -C "$R" config user.email t@t && git -C "$R" config user.name t
echo a >"$R/a.txt" && git -C "$R" add . && git -C "$R" commit -qm init
export COP_WORKTREE_DIR="$T/wts"
"$COP" -W -C "$T/proj" "x" >/dev/null 2>&1; st=$?
check "-W fora de git = 4" '[ $st = 4 ]'
out=$(cd "$R" && FAKE_WRITE=novo.txt "$COP" -W "crie novo.txt")
JOB=$(echo "$out" | sed -n 's/.*job=\([^ ]*\).*/\1/p' | head -1)
WTP=$(ls -d "$T/wts"/repo-* | head -1)
check "-W roda no worktree, não no repo" '[ -f "$WTP/novo.txt" ] && [ ! -f "$R/novo.txt" ]'
check "-W mostra diffstat e como aplicar" 'echo "$out" | grep -q "novo.txt" && echo "$out" | grep -q "cop --apply $JOB"'
check "--jobs lista o job" '"$COP" --jobs | grep "$JOB" >/dev/null'
(cd "$R" && "$COP" --apply "$JOB" >/dev/null)
check "--apply traz as mudanças e remove o worktree" '[ -f "$R/novo.txt" ] && [ ! -d "$WTP" ] && ! git -C "$R" branch | grep -q "cop/"'
out=$(cd "$R" && FAKE_WRITE=lixo.txt "$COP" -W "x")
JOB2=$(echo "$out" | sed -n 's/.*job=\([^ ]*\).*/\1/p' | head -1)
"$COP" --discard "$JOB2" >/dev/null
check "--discard remove sem aplicar" '[ ! -f "$R/lixo.txt" ] && [ -z "$(ls "$T/wts")" ]'
"$COP" --apply "$JOB2" >/dev/null 2>&1; st=$?
check "--apply de job descartado = 4" '[ $st = 4 ]'
"$COP" -W -r last "x" >/dev/null 2>&1; st=$?
check "-W com -r = 2" '[ $st = 2 ]'

check "--stats" '"$COP" --stats | grep -q "delegações:"'
check "--last" '[ -f "$("$COP" --last)" ]'

echo "---- $PASS ok, $FAIL falhas"
[ "$FAIL" = 0 ]
