#!/usr/bin/env bash
# fanout-plan.sh — 多模型规划面板: 把"拆解目标"同时发给 N 个规划模型, 各自 Write 方案,
#                  由 planner(Claude) 综合。是 design panel 模式。
#   fanout-plan.sh "<goal>" [--models m1,m2,..] [--out <dir>]
#   默认 models = cc-deepseek,cc-kimi,coder   (跨家拿不同视角)
#   默认 out    = <cache_root>/plans
#   env: FANOUT_CCB(stub 可测) / FANOUT_CACHE
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
die(){ echo "fanout-plan: $*" >&2; exit 2; }

goal="${1:-}"; shift || true
[ -n "$goal" ] || die "用法: \"<goal>\" [--models m1,m2,..] [--out <dir>]"
models="cc-deepseek,cc-kimi,coder"
CACHE_ROOT="${FANOUT_CACHE:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)/.fanout-cache}"
out="$CACHE_ROOT/plans"
while [ "$#" -gt 0 ]; do
  case "$1" in
    --models) models="${2:-}"; shift 2;;
    --out) out="${2:-}"; shift 2;;
    *) die "未知参数 '$1'";;
  esac
done
mkdir -p "$out"

echo "── 规划面板: 目标拆解 → ${models//,/ } ──"
IFS=',' read -ra MS <<< "$models"
files=()
for m in "${MS[@]}"; do
  [ -n "$m" ] || continue
  of="$out/$m.plan.md"; files+=("$of")
  bash "$HERE/fanout-dispatch.sh" "$m" --template plan \
    --set MODEL="$m" --set GOAL="$goal" --set OUTFILE="$of" >/dev/null 2>&1 \
    && echo "  → 派给 $m, 方案将写到 $of" \
    || echo "  ✗ $m 派活失败"
done
echo ""
echo "收集: 各模型写完后, planner 读这些方案综合成最终 plan:"
for f in "${files[@]}"; do echo "  $f"; done
