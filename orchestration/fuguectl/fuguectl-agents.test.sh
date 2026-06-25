#!/usr/bin/env bash
# fuguectl-agents.test.sh — Agent Runtime Registry shell helper tests
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
A="$HERE/fuguectl-agents.sh"
FG="$HERE/fuguectl"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
# shellcheck source=/dev/null
. "$HERE/fuguectl-testlib.sh"

echo "fuguectl-agents tests"

REG="$TMP/agents.json"
bash "$A" template > "$REG"
ok "template writes agents array" 'grep -q "\"agents\"" "$REG"'
ok "template includes codex reviewer profile" 'grep -q "\"harness\": \"codex\"" "$REG" && grep -q "\"id\": \"coder\"" "$REG"'

out="$(bash "$A" validate "$REG")"
ok "validate accepts template" 'echo "$out" | grep -q "OK agent registry valid: 3 agents"'

list="$(bash "$A" list "$REG")"
ok "list includes coder target" 'echo "$list" | grep -q "$(printf "coder\tcodex\tgpt-5.5")"'

resolved="$(bash "$A" resolve "$REG" coder)"
ok "resolve prints harness" 'echo "$resolved" | grep -q "$(printf "harness\tcodex")"'
ok "resolve prints target" 'echo "$resolved" | grep -q "$(printf "target\tgpt-5.5")"'

top="$(bash "$FG" agents template)"
ok "top-level agents entrypoint works" 'echo "$top" | grep -q "\"opencode\""'

cat > "$TMP/dupe.json" <<'JSON'
{"agents":[{"id":"coder","harness":"codex"},{"id":"coder","harness":"opencode"}]}
JSON
bash "$A" validate "$TMP/dupe.json" >/dev/null 2>&1
ok "duplicate id rejected" '[ "$?" -ne 0 ]'

cat > "$TMP/bad-harness.json" <<'JSON'
{"agents":[{"id":"bad","harness":"claude-code"}]}
JSON
bash "$A" validate "$TMP/bad-harness.json" >/dev/null 2>&1
ok "invalid harness rejected" '[ "$?" -ne 0 ]'

bash "$A" resolve "$REG" missing-agent >/dev/null 2>&1
ok "unknown agent rejected" '[ "$?" -ne 0 ]'

bash "$A" nope >/dev/null 2>&1
ok "unknown subcommand rejected" '[ "$?" -ne 0 ]'

tdone
