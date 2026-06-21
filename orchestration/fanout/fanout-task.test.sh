#!/usr/bin/env bash
# fanout-task.test.sh — fanout-task.sh 自测
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
T="$HERE/fanout-task.sh"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
export TASKS="$TMP/tasks"

pass=0; fail=0
ok(){ if eval "$2"; then echo "  ✓ $1"; pass=$((pass+1)); else echo "  ✗ $1"; fail=$((fail+1)); fi; }

echo "fanout-task tests"

F="$(bash "$T" new "测试任务标题" P0)"
ok "new 返回路径且文件存在" '[ -f "$F" ]'
ok "new 文件名形如 TASK-<date>-NNN.md" 'echo "$F" | grep -qE "TASK-[0-9]{4}-[0-9]{2}-[0-9]{2}-[0-9]{3}\.md$"'
ok "Status: IN_PROGRESS" 'grep -q "^Status: IN_PROGRESS" "$F"'
ok "Priority 写入 P0" 'grep -q "^Priority: P0" "$F"'
ok "标题进了标题行" 'grep -q "测试任务标题" "$F"'
ok "有 执行日志 段" 'grep -q "^## 执行日志" "$F"'

# new 第二次应递增编号 (不覆盖)
F2="$(bash "$T" new "第二个" )"
ok "second new 不同文件" '[ "$F" != "$F2" ]'

bash "$T" log "$F" "第一条日志" >/dev/null
ok "log 追加到文件" 'grep -q "第一条日志" "$F"'
ok "log 带时间戳" 'grep -qE "^- \[[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}\] 第一条日志" "$F"'

bash "$T" "done" "$F" >/dev/null
ok "done → Status: DONE" 'grep -q "^Status: DONE" "$F"'
ok "done 写了 Completed 时间" 'grep -qE "^Completed: [0-9]{4}-" "$F"'
ok "done 不再是 IN_PROGRESS" '! grep -q "^Status: IN_PROGRESS" "$F"'

# 错误用法
bash "$T" new >/dev/null 2>&1; ok "new 无标题 → 非0退出" '[ "$?" -ne 0 ]'
bash "$T" log /no/such/file x >/dev/null 2>&1; ok "log 不存在文件 → 非0" '[ "$?" -ne 0 ]'

echo "fanout-task: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
