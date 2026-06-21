#!/usr/bin/env bash
# fanout-allocate.sh — 按任务类型查 bench 推荐模型 (源 allocation.tsv)
#   <task-type>          打印 ranked 模型 (逗号, 第一=首选)
#   <task-type> --top    只打印首选模型
#   list                 打印全表
#   未知类型 → 回退 fallback 行 (mimo), 并在 stderr 提示
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TBL="${FANOUT_ALLOCATION:-$HERE/allocation.tsv}"
die(){ echo "fanout-allocate: $*" >&2; exit 2; }
[ -f "$TBL" ] || die "无 allocation 表 $TBL"

lookup(){ grep -vE '^[[:space:]]*#' "$TBL" | awk -F'\t' -v k="$1" '$1==k{print $2; found=1} END{exit !found}'; }

sub="${1:-}"
[ -n "$sub" ] || die "用法: <task-type> [--top] | list"

if [ "$sub" = "list" ]; then
  grep -vE '^[[:space:]]*#|^[[:space:]]*$' "$TBL" | awk -F'\t' '{printf "  %-14s %s\n",$1,$2}'
  exit 0
fi

top=0; [ "${2:-}" = "--top" ] && top=1
if models="$(lookup "$sub")"; then :; else
  models="$(lookup fallback)" || die "表里连 fallback 都没有"
  echo "fanout-allocate: 未知任务类型 '$sub' → 回退 fallback ($models)" >&2
fi
[ "$top" -eq 1 ] && printf '%s\n' "${models%%,*}" || printf '%s\n' "$models"
