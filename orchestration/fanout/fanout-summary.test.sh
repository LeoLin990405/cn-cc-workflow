#!/usr/bin/env bash
# fanout-summary.test.sh
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
S="$HERE/fanout-summary.sh"; C="$HERE/fanout-cache.sh"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
export FANOUT_CACHE="$TMP/cache"
pass=0; fail=0
ok(){ if eval "$2"; then echo "  ✓ $1"; pass=$((pass+1)); else echo "  ✗ $1"; fail=$((fail+1)); fi; }

echo "fanout-summary tests"
echo r > "$TMP/a.md"

bash "$C" init 1 t1:cc-deepseek t2:cc-glm >/dev/null
bash "$C" put 1 t1 "$TMP/a.md" >/dev/null
bash "$C" fail 1 t2 "超时" >/dev/null

out="$(bash "$S" 1)"
ok "汇总含 Round 1 标题" 'echo "$out" | grep -q "Round 1 汇总"'
ok "汇总含计数 done=1 fail=1" 'echo "$out" | grep -q "done=1 fail=1"'
ok "汇总列出任务明细" 'echo "$out" | grep -q "t1" && echo "$out" | grep -q "cc-glm"'

# --task 写入
TASKF="$TMP/task.md"; printf '## 执行日志\n' > "$TASKF"
bash "$S" 1 --task "$TASKF" >/dev/null 2>&1
ok "--task 把汇总写进文件" 'grep -q "Round 1 汇总" "$TASKF"'

# 未 init 的 round → 非0
bash "$S" 9 >/dev/null 2>&1; ok "未 init round → 非0" '[ "$?" -ne 0 ]'

echo "fanout-summary: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
