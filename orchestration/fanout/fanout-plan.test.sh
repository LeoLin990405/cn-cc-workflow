#!/usr/bin/env bash
# fanout-plan.test.sh — stub ccb 测规划面板派活
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
P="$HERE/fanout-plan.sh"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
export FANOUT_CACHE="$TMP/cache"
pass=0; fail=0
ok(){ if eval "$2"; then echo "  ✓ $1"; pass=$((pass+1)); else echo "  ✗ $1"; fail=$((fail+1)); fi; }

# stub ccb: 记录被叫的 agent($2), 消费 stdin
printf '#!/usr/bin/env bash\necho "$2" >> "%s"\ncat >/dev/null\n' "$TMP/calls" > "$TMP/ccb"
chmod +x "$TMP/ccb"; export FANOUT_CCB="$TMP/ccb"

echo "fanout-plan tests"

out="$(bash "$P" "做一个登录功能" --models cc-a,cc-b)"
ok "派给 2 个指定模型" '[ "$(grep -c . "$TMP/calls")" -eq 2 ]'
ok "calls 含 cc-a 和 cc-b" 'grep -q cc-a "$TMP/calls" && grep -q cc-b "$TMP/calls"'
ok "输出列出 plan 文件路径" 'echo "$out" | grep -q "cc-a.plan.md"'

: > "$TMP/calls"
bash "$P" "默认模型测试" >/dev/null 2>&1
ok "默认 models = 3 家" '[ "$(grep -c . "$TMP/calls")" -eq 3 ]'

bash "$P" >/dev/null 2>&1; ok "无 goal → 非0" '[ "$?" -ne 0 ]'

echo "fanout-plan: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
