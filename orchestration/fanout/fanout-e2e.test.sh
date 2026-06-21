#!/usr/bin/env bash
# fanout-e2e.test.sh — 端到端集成: allocate → init → dispatch(stub) → put → barrier
#                      → resume → 再 put → barrier 放行 → summary → collect
# 证明各工具组合成完整生命周期 (不碰真 ccb)。
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
C="$HERE/fanout-cache.sh"; D="$HERE/fanout-dispatch.sh"; S="$HERE/fanout-summary.sh"; AL="$HERE/fanout-allocate.sh"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
export FANOUT_CACHE="$TMP/cache"
pass=0; fail=0
ok(){ if eval "$2"; then echo "  ✓ $1"; pass=$((pass+1)); else echo "  ✗ $1"; fail=$((fail+1)); fi; }

# stub ccb (dispatch 用)
printf '#!/usr/bin/env bash\nexit 0\n' > "$TMP/ccb"; chmod +x "$TMP/ccb"; export FANOUT_CCB="$TMP/ccb"
echo p > "$TMP/p.md"; echo r > "$TMP/r.md"

echo "fanout-e2e tests"

# 1) bench 分配决定模型
ok "allocate code → minimax" '[ "$(bash "$AL" code --top)" = "minimax" ]'

# 2) init 本轮 3 个任务
bash "$C" init 1 t1:cc-minimax t2:cc-kimi t3:cc-glm >/dev/null
ok "init 声明 3 任务" '[ "$(wc -l <"$FANOUT_CACHE/round-1/manifest.tsv")" -eq 3 ]'

# 3) dispatch (stub ccb 不报错)
bash "$D" cc-minimax --prompt-file "$TMP/p.md" >/dev/null 2>&1
ok "dispatch 经 stub 成功" '[ "$?" -eq 0 ]'

# 4) put 2/3, barrier 应挡住
bash "$C" put 1 t1 "$TMP/r.md" >/dev/null
bash "$C" put 1 t2 "$TMP/r.md" >/dev/null
bash "$C" barrier 1 >/dev/null 2>&1; ok "barrier 2/3 挡住" '[ "$?" -ne 0 ]'

# 5) resume 只列未返回的 t3
res="$(bash "$C" resume 1)"
ok "resume 列出未返回 t3" 'echo "$res" | grep -q "^t3"'
ok "resume 不含已返回 t1/t2" '! echo "$res" | grep -qE "^t1|^t2"'

# 6) 补 t3, barrier 放行
bash "$C" put 1 t3 "$TMP/r.md" >/dev/null
bash "$C" barrier 1 >/dev/null 2>&1; ok "barrier 3/3 放行" '[ "$?" -eq 0 ]'
ok "resume 此时为空" '[ -z "$(bash "$C" resume 1)" ]'

# 7) summary: 耗时 + done=3
out="$(bash "$S" 1)"
ok "summary 含耗时" 'echo "$out" | grep -q "耗时"'
ok "summary done=3" 'echo "$out" | grep -q "done=3"'

# 8) collect 3 个 result
ok "collect 出 3 个 result" '[ "$(bash "$C" collect 1 | grep -c .)" -eq 3 ]'

echo "fanout-e2e: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
