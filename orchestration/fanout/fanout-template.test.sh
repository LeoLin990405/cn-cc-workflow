#!/usr/bin/env bash
# fanout-template.test.sh
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
T="$HERE/fanout-template.sh"
pass=0; fail=0
ok(){ if eval "$2"; then echo "  ✓ $1"; pass=$((pass+1)); else echo "  ✗ $1"; fail=$((fail+1)); fi; }

echo "fanout-template tests"

out="$(bash "$T" impl --set ROLE=后端 --set SCOPE=写解析器 --set FILES=src/p.py)"
ok "impl 模板渲染含替换值" 'echo "$out" | grep -q "你的角色：后端" && echo "$out" | grep -q "写解析器" && echo "$out" | grep -q "src/p.py"'
ok "已 set 的占位被替换掉" '! echo "$out" | grep -q "{{ROLE}}"'

# 未 set 的占位保留
out2="$(bash "$T" impl --set ROLE=x)"
ok "未 set 的 {{SCOPE}} 保留" 'echo "$out2" | grep -q "{{SCOPE}}"'

# review / analysis 模板存在
ok "review 模板可渲染" 'bash "$T" review --set REVIEWER=Codex --set DIFF_RANGE=main...HEAD --set DIFF=x | grep -q "VERDICT: ACCEPTED"'
ok "analysis 模板可渲染" 'bash "$T" analysis --set ROLE=审查 | grep -q "必须用 Write 工具"'

# 错误
bash "$T" >/dev/null 2>&1; ok "无名 → 非0" '[ "$?" -ne 0 ]'
bash "$T" nope >/dev/null 2>&1; ok "未知模板 → 非0" '[ "$?" -ne 0 ]'
bash "$T" impl --set BADFORMAT >/dev/null 2>&1; ok "--set 无 = → 非0" '[ "$?" -ne 0 ]'

echo "fanout-template: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
