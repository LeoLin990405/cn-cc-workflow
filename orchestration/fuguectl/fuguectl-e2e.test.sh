#!/usr/bin/env bash
# fuguectl-e2e.test.sh — end-to-end integration: allocate → init → dispatch(stub) → put → barrier
#                      → resume → put again → barrier passes → summary → collect
# Proves the tools compose into a full lifecycle (without touching real fugue-cc).
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
F="$HERE/fuguectl"; C="$HERE/fuguectl-cache"; D="$HERE/fuguectl-dispatch"; S="$HERE/fuguectl-summary"; AL="$HERE/fuguectl-allocate"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
export FUGUE_CACHE="$TMP/cache"
# shellcheck source=/dev/null
. "$HERE/fuguectl-testlib.sh"

# stub fugue-cc (used by dispatch)
printf '#!/usr/bin/env bash\nexit 0\n' > "$TMP/fugue-cc"; chmod +x "$TMP/fugue-cc"; export FUGUE_CC_BIN="$TMP/fugue-cc"
echo p > "$TMP/p.md"; echo r > "$TMP/r.md"

echo "fuguectl-e2e tests"

# 1) top-level help stays within the comment block
help_out="$("$F" help)"
ok "help lists subcommands" '[[ "$help_out" == *"fuguectl doctor"* ]]'
ok "help lists runtime entrypoint" '[[ "$help_out" == *"fuguectl runtime"* ]]'
ok "help lists agents entrypoint" '[[ "$help_out" == *"fuguectl agents"* ]]'
ok "help does not leak script body" '[[ "$help_out" != *"set -uo pipefail"* ]]'
fuguectl_ws_out="$("$F" workspace list)"
ok "fuguectl dispatches commands" 'grep -q "^  code" <<<"$fuguectl_ws_out"'

# 2) bench allocation decides the model
ok "allocate code → minimax" '[ "$("$AL" code --top)" = "minimax" ]'

# 3) init this round's 3 tasks
"$C" init 1 t1:cc-minimax t2:cc-kimi t3:cc-glm >/dev/null
ok "init declares 3 tasks" '[ "$(wc -l <"$FUGUE_CACHE/round-1/manifest.tsv")" -eq 3 ]'

# 4) dispatch (stub fugue-cc doesn't error)
"$D" cc-minimax --prompt-file "$TMP/p.md" >/dev/null 2>&1
ok "dispatch succeeds via stub" '[ "$?" -eq 0 ]'

# 5) put 2/3, barrier should block
"$C" put 1 t1 "$TMP/r.md" >/dev/null
"$C" put 1 t2 "$TMP/r.md" >/dev/null
"$C" barrier 1 >/dev/null 2>&1; ok "barrier 2/3 blocks" '[ "$?" -ne 0 ]'

# 6) resume lists only the un-returned t3
res="$("$C" resume 1)"
ok "resume lists un-returned t3" 'echo "$res" | grep -q "^t3"'
ok "resume excludes returned t1/t2" '! echo "$res" | grep -qE "^t1|^t2"'

# 7) fill t3, barrier passes
"$C" put 1 t3 "$TMP/r.md" >/dev/null
"$C" barrier 1 >/dev/null 2>&1; ok "barrier 3/3 passes" '[ "$?" -eq 0 ]'
ok "resume is now empty" '[ -z "$("$C" resume 1)" ]'

# 8) summary: elapsed + done=3
out="$("$S" 1)"
ok "summary has elapsed" 'echo "$out" | grep -q "elapsed"'
ok "summary done=3" 'echo "$out" | grep -q "done=3"'

# 9) collect 3 results
ok "collect emits 3 results" '[ "$("$C" collect 1 | grep -c .)" -eq 3 ]'

tdone
