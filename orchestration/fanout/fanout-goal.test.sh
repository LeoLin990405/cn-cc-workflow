#!/usr/bin/env bash
# fanout-goal.test.sh
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
G="$HERE/fanout-goal.sh"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
pass=0; fail=0
ok(){ if eval "$2"; then echo "  ✓ $1"; pass=$((pass+1)); else echo "  ✗ $1"; fail=$((fail+1)); fi; }

echo "fanout-goal tests"

ok "template 含 outcome+gate" 'bash "$G" template | grep -q "outcome:" && bash "$G" template | grep -q "gate:"'

printf 'outcome: 示例\ngate: true\nrubric: 无回归\nrounds: 2\n' > "$TMP/g.spec"
bash "$G" check "$TMP/g.spec" >/dev/null 2>&1; ok "gate=true → check 达成(0)" '[ "$?" -eq 0 ]'

printf 'outcome: 坏\ngate: false\n' > "$TMP/bad.spec"
bash "$G" check "$TMP/bad.spec" >/dev/null 2>&1; ok "gate=false → 未达成(非0)" '[ "$?" -ne 0 ]'

# 注: 捕获后用 here-string grep, 避免 pipefail + grep -q 提前关管道致生产者 SIGPIPE(141)
ok "show 解析 outcome=示例" 'o=$(bash "$G" show "$TMP/g.spec"); grep -q "outcome:  示例" <<<"$o"'
ok "show 解析 rounds=2" 'o=$(bash "$G" show "$TMP/g.spec"); grep -q "rounds:   2" <<<"$o"'

# gate 含 && 复合命令
printf 'outcome: x\ngate: true && true\n' > "$TMP/cmp.spec"
bash "$G" check "$TMP/cmp.spec" >/dev/null 2>&1; ok "复合 gate(&&) 正确求值" '[ "$?" -eq 0 ]'

printf 'outcome: 无门\n' > "$TMP/nogate.spec"
bash "$G" check "$TMP/nogate.spec" >/dev/null 2>&1; ok "无 gate 行 → 非0" '[ "$?" -ne 0 ]'
bash "$G" check /no/such >/dev/null 2>&1; ok "spec 不存在 → 非0" '[ "$?" -ne 0 ]'
bash "$G" bogus >/dev/null 2>&1; ok "未知子命令 → 非0" '[ "$?" -ne 0 ]'

echo "fanout-goal: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
