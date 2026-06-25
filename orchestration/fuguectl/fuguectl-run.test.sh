#!/usr/bin/env bash
# fuguectl-run.test.sh — self-test for the run shell bridge.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
R="$HERE/fuguectl-run"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
export FUGUE_CACHE="$TMP/cache"
export FUGUE_ENGINE_CLI="$TMP/fugue-engine"
export FUGUE_RUN_CALLS="$TMP/run-calls.txt"

# shellcheck source=/dev/null
. "$HERE/fuguectl-testlib.sh"

cat > "$FUGUE_ENGINE_CLI" <<'EOF'
const fs = require('node:fs');

fs.appendFileSync(process.env.FUGUE_RUN_CALLS, `${process.argv.slice(2).join(' ')}\n`);
const args = process.argv.slice(2);
if (args[0] !== 'run') {
  console.error('expected run root command');
  process.exit(2);
}
process.exit(0);
EOF
chmod +x "$FUGUE_ENGINE_CLI"

echo "fuguectl-run tests"

"$R" set --task "$TMP/TASK.md" --round 2 >/dev/null
ok "run shim forwards set" 'grep -q "^run set --task $TMP/TASK.md --round 2$" "$FUGUE_RUN_CALLS"'

"$R" status --human >/dev/null
ok "run shim preserves status flags" 'grep -q "^run status --human$" "$FUGUE_RUN_CALLS"'

help="$("$R" --help)"
ok "help prints run commands" 'echo "$help" | grep -q "status \[--human\]"'
ok "help does not call engine" '[ "$(grep -c . "$FUGUE_RUN_CALLS")" -eq 2 ]'

tdone
