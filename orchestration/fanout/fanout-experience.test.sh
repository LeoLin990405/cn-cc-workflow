#!/usr/bin/env bash
# fanout-experience.test.sh
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
E="$HERE/fanout-experience.sh"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
export FANOUT_EXPERIENCE="$TMP/exp"
pass=0; fail=0
ok(){ if eval "$2"; then echo "  ✓ $1"; pass=$((pass+1)); else echo "  ✗ $1"; fail=$((fail+1)); fi; }

echo "fanout-experience tests"

# add via stdin
echo "用 defensive copy(intervals[0][:]) 避免改输入区间" | bash "$E" add code "防御拷贝技巧" >/dev/null
ok "add 落库" '[ -f "$FANOUT_EXPERIENCE/code/防御拷贝技巧.md" ]'
ok "记录含 body" 'grep -q "defensive copy" "$FANOUT_EXPERIENCE/code/防御拷贝技巧.md"'
ok "记录有 frontmatter" 'grep -q "^workspace: code" "$FANOUT_EXPERIENCE/code/防御拷贝技巧.md"'

# 脱敏: body 含明文 key → 拒绝 (运行时拼 fake key, 不在文件留 sk- 字面, 免 scan-secrets 误报)
FAKEKEY="sk-$(printf 'a%.0s' $(seq 25))"
echo "用这个 key $FAKEKEY" | bash "$E" add code "坏经验" >/dev/null 2>&1
ok "含 key → 拒绝(非0)" '[ "$?" -ne 0 ]'
ok "坏经验未落库" '[ ! -f "$FANOUT_EXPERIENCE/code/坏经验.md" ]'

# list (capture 防 SIGPIPE)
ok "list 含标题" 'o=$(bash "$E" list code); grep -q 防御拷贝 <<<"$o"'

# recall
out="$(bash "$E" recall code)"
ok "recall 出 body" 'echo "$out" | grep -q "defensive copy"'
ok "recall 带【经验】标记" 'echo "$out" | grep -q "【经验】"'
ok "recall 不漏 frontmatter(无 created:)" '! echo "$out" | grep -q "^created:"'

# 空 ws → 空输出, 0 退出
ok "recall 空 ws → 空" '[ -z "$(bash "$E" recall nonexistent)" ]'

# query 过滤
echo "qwen3 SQL 近30天用 DATE_SUB(CURDATE(),INTERVAL 30 DAY)" | bash "$E" add sql "SQL日期窗口" >/dev/null
ok "recall --query 命中" 'o=$(bash "$E" recall sql --query DATE_SUB); grep -q DATE_SUB <<<"$o"'

# show
ok "show 打印记录" 'o=$(bash "$E" show code 防御拷贝技巧); grep -q "title: 防御拷贝技巧" <<<"$o"'

# 集成: workspace context 注入该 ws 经验 (FANOUT_EXPERIENCE 已 export)
ctx="$(bash "$HERE/fanout-workspace.sh" context code)"
ok "workspace context 注入经验" 'echo "$ctx" | grep -q "defensive copy"'

echo "fanout-experience: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
