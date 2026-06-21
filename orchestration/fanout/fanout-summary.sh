#!/usr/bin/env bash
# fanout-summary.sh — round 可观测: 缓存状态汇总表 (可选写进 TASK 文件)
#   fanout-summary.sh <round> [--task <file>]
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CACHE="$HERE/fanout-cache.sh"
die(){ echo "fanout-summary: $*" >&2; exit 2; }

round="${1:-}"; shift || true
[ -n "$round" ] || die "用法: <round> [--task <file>]"
task=""
while [ "$#" -gt 0 ]; do case "$1" in --task) task="${2:-}"; shift 2;; *) die "未知参数 '$1'";; esac; done

st="$(bash "$CACHE" status "$round")" || die "round-$round 未 init"
# 计时 (cache 在 init 写 .started, put/fail 写 <id>.at)
CACHE_ROOT="${FANOUT_CACHE:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)/.fanout-cache}"
d="$CACHE_ROOT/round-$round"; elapsed="?"
[ -f "$d/.started" ] && elapsed="$(( $(date +%s) - $(cat "$d/.started") ))s"
summary="$( { echo "### Round $round 汇总 — $st — 耗时 $elapsed"; bash "$CACHE" list "$round"; } )"
printf '%s\n' "$summary"

if [ -n "$task" ]; then
  [ -f "$task" ] || die "无 TASK 文件 $task"
  printf '\n%s\n' "$summary" >> "$task"
  echo "→ 已写入 $task" >&2
fi
