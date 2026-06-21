#!/usr/bin/env bash
# fanout-workspace.test.sh
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
W="$HERE/fanout-workspace.sh"
pass=0; fail=0
ok(){ if eval "$2"; then echo "  ✓ $1"; pass=$((pass+1)); else echo "  ✗ $1"; fail=$((fail+1)); fi; }

echo "fanout-workspace tests"

ok "list 列出 >=6 工位" '[ "$(bash "$W" list | grep -c .)" -ge 6 ]'
ok "list 含 code/review/main" 'o=$(bash "$W" list); grep -q code <<<"$o" && grep -q review <<<"$o" && grep -q main <<<"$o"'

ok "show code 含 models 字段" 'bash "$W" show code | grep -q "^models:"'

# model: @bench:code → 经 allocation 解析成 minimax,...
ok "model code → bench 解析含 minimax" 'bash "$W" model code | grep -q minimax'
ok "model review → coder" '[ "$(bash "$W" model review)" = "coder" ]'

# context: 五层齐全 (Zleap 格式)
ctx="$(bash "$W" context code)"
for sec in "System Prompt" "Workspace Prompt" "### Tools" "### Memory" "### History"; do
  ok "context 含 [$sec]" 'echo "$ctx" | grep -q "$sec"'
done
ok "context 带入全局 no-Gemini 规则" 'echo "$ctx" | grep -q "不调用 Gemini"'
ok "context code 只暴露本工位 tools(含 edit)" 'echo "$ctx" | grep -q "edit"'

# --task 注入 (捕获后 here-string grep, 避免 pipefail+grep -q SIGPIPE)
ok "context --task 注入任务" 'o=$(bash "$W" context code --task "做X"); grep -q "做X" <<<"$o"'

bash "$W" context nope >/dev/null 2>&1; ok "未知 workspace → 非0" '[ "$?" -ne 0 ]'
o=$(bash "$W" 2>&1); ok "无子命令 → 显示帮助(含 list)" 'grep -q list <<<"$o"'

echo "fanout-workspace: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
