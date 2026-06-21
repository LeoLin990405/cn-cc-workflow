#!/usr/bin/env bash
# fanout-cache.test.sh — fanout-cache.sh 的自测 (CI / 本地)
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CACHE="$HERE/fanout-cache.sh"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
export FANOUT_CACHE="$TMP/cache"
cd "$TMP" || exit 1

pass=0; fail=0
ok()  { if eval "$2"; then echo "  ✓ $1"; pass=$((pass+1)); else echo "  ✗ $1"; fail=$((fail+1)); fi; }

echo "fanout-cache tests"

# 准备 3 个假产物
echo "r1" > a.md; echo "r2" > b.md; echo "r3" > c.md

# init: 声明本轮 3 个任务
bash "$CACHE" init 1 t1:cc-deepseek t2:cc-glm t3:agy >/dev/null
ok "init 写 manifest 3 行" '[ "$(wc -l <"$FANOUT_CACHE/round-1/manifest.tsv")" -eq 3 ]'

# barrier 在 0/3 时必须失败 (不许进下一轮)
bash "$CACHE" barrier 1 >/dev/null 2>&1; ok "barrier 0/3 → 非 0 退出" '[ "$?" -ne 0 ]'

# put 两个
bash "$CACHE" put 1 t1 a.md >/dev/null
bash "$CACHE" put 1 t2 b.md >/dev/null
ok "put 后 result 落缓存" '[ -f "$FANOUT_CACHE/round-1/t1.result" ]'

# barrier 在 2/3 仍失败
bash "$CACHE" barrier 1 >/dev/null 2>&1; ok "barrier 2/3 → 仍非 0 (N!=N)" '[ "$?" -ne 0 ]'

# 拒绝不在 manifest 的任务
bash "$CACHE" put 1 t9 c.md >/dev/null 2>&1; ok "put 未声明任务 t9 → 拒绝" '[ "$?" -ne 0 ]'

# 第 3 个用 fail (失败也算"已返回")
bash "$CACHE" fail 1 t3 "agy 超时" >/dev/null
bash "$CACHE" barrier 1 >/dev/null 2>&1; ok "barrier 3/3 (含 1 fail) → 0 退出, 可进下一轮" '[ "$?" -eq 0 ]'

# --require-success 时有 fail 必须挡住
bash "$CACHE" barrier 1 --require-success >/dev/null 2>&1; ok "barrier --require-success 有 fail → 非 0" '[ "$?" -ne 0 ]'

# collect 只吐 done 的 result (t1,t2; t3 是 fail 无 result)
ok "collect 输出 2 个 result 路径" '[ "$(bash "$CACHE" collect 1 | grep -c .)" -eq 2 ]'

# status 计数正确
ok "status done=2 fail=1" 'bash "$CACHE" status 1 | grep -q "done=2 fail=1"'

# 全 done 的一轮 → --require-success 通过
bash "$CACHE" init 2 x:cc-mimo >/dev/null
bash "$CACHE" put 2 x a.md >/dev/null
bash "$CACHE" barrier 2 --require-success >/dev/null 2>&1; ok "全 done 轮 --require-success → 0" '[ "$?" -eq 0 ]'

echo "fanout-cache: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
