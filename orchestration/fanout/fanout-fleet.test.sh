#!/usr/bin/env bash
# fanout-fleet.test.sh — 测 up --dry(命令/剥离) + status(stub) + down; 绝不真起 fleet
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
F="$HERE/fanout-fleet.sh"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/work/.ccb" "$TMP/claude/.ccb"
export CCB_WORK="$TMP/work" CCB_CLAUDE="$TMP/claude"
export CLAUDE_CODE_TEST_X=1   # 模拟会泄漏给子 cc-* 的 OAuth env
pass=0; fail=0
ok(){ if eval "$2"; then echo "  ✓ $1"; pass=$((pass+1)); else echo "  ✗ $1"; fail=$((fail+1)); fi; }

# not-ready stub (ping 无 health)
notready(){ printf '#!/usr/bin/env bash\nexit 0\n' > "$TMP/ccb"; chmod +x "$TMP/ccb"; }
# ready stub (ping ccbd → health)
ready(){ printf '#!/usr/bin/env bash\ncase "$1 $2" in "ping ccbd") echo "ccbd health: alive";; esac\nexit 0\n' > "$TMP/ccb"; chmod +x "$TMP/ccb"; }
export FANOUT_CCB="$TMP/ccb"

echo "fanout-fleet tests"

notready
out="$(bash "$F" up --dry)"
ok "up --dry 剥离 CLAUDE_CODE_*(含 TEST_X)" 'echo "$out" | grep -q -- "-u CLAUDE_CODE_TEST_X"'
ok "up --dry 含 ccb -s 启动" 'echo "$out" | grep -q "ccb -s"'
ok "up --dry 覆盖两个项目" 'echo "$out" | grep -q work && echo "$out" | grep -q claude'
ok "claude 池带 CLAUDE_START_CMD 前缀" 'echo "$out" | grep claude | grep -q "CLAUDE_START_CMD=claude"'
ok "work 池不带 claude 前缀" '! (echo "$out" | grep "/work " | grep -q "CLAUDE_START_CMD")'

# pty.fork 兜底 dry
outp="$(bash "$F" up --pty --dry)"
ok "up --pty --dry 走 fleet-launch.py" 'echo "$outp" | grep -q fleet-launch.py'
ok "up --pty --dry 含 ccb -s" 'echo "$outp" | grep -q "ccb -s"'

# fleet-launch.py 真机制(无害命令): 剥 CLAUDE_CODE_* + 在 project 内跑 + detach
if command -v python3 >/dev/null 2>&1; then
  rm -f "$TMP/work/launch.out"
  python3 "$HERE/fleet-launch.py" "$TMP/work" sh -c 'env > launch.out'
  sleep 1
  ok "fleet-launch 在 project 内执行(cwd 证明)" '[ -f "$TMP/work/launch.out" ]'
  ok "fleet-launch 剥掉 CLAUDE_CODE_*" '[ -f "$TMP/work/launch.out" ] && ! grep -q CLAUDE_CODE_TEST_X "$TMP/work/launch.out"'
  python3 "$HERE/fleet-launch.py" >/dev/null 2>&1; ok "fleet-launch 无参 → 非0" '[ "$?" -ne 0 ]'
fi

ok "status(not-ready) 报 down" 'o=$(bash "$F" status 2>&1); grep -q down <<<"$o"'

ready
ok "status(ready stub) 报 ready" 'o=$(bash "$F" status 2>&1); grep -q ready <<<"$o"'

bash "$F" down >/dev/null 2>&1; ok "down 不报错" '[ "$?" -eq 0 ]'
bash "$F" bogus >/dev/null 2>&1; ok "未知子命令 → 非0" '[ "$?" -ne 0 ]'

echo "fanout-fleet: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
