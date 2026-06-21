#!/usr/bin/env bash
# fanout-allocate.test.sh
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
A="$HERE/fanout-allocate.sh"
pass=0; fail=0
ok(){ if eval "$2"; then echo "  ✓ $1"; pass=$((pass+1)); else echo "  ✗ $1"; fail=$((fail+1)); fi; }

echo "fanout-allocate tests"
ok "code → minimax 首位" '[ "$(bash "$A" code)" = "minimax,doubao,glm" ]'
ok "logic --top → kimi" '[ "$(bash "$A" logic --top)" = "kimi" ]'
ok "sql 含 doubao" 'bash "$A" sql | grep -q doubao'
ok "review → coder" '[ "$(bash "$A" review --top)" = "coder" ]'
ok "list 输出多行" '[ "$(bash "$A" list | grep -c .)" -ge 8 ]'
out="$(bash "$A" bogusXYZ 2>/dev/null)"; ok "未知类型回退 mimo (stdout)" '[ "$out" = "mimo" ]'
bash "$A" bogusXYZ 2>&1 1>/dev/null | grep -q "回退 fallback"; ok "未知类型 stderr 提示" '[ "$?" -eq 0 ]'
bash "$A" >/dev/null 2>&1; ok "无参 → 非0" '[ "$?" -ne 0 ]'

echo "fanout-allocate: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
