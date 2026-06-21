#!/usr/bin/env bash
# fanout-task.sh — TASK 文件脚手架 + 日志 + 收尾 (替代手抄 TASK 模板)
#
#   new  "<title>" [P0|P1|P2]     在 $TASKS 建 TASK-<date>-<NNN>.md, 打印路径
#   log  <task-file> "<message>"  追加时间戳日志到「执行日志」段
#   done <task-file>              Status: DONE + Completed 时间
#   env: TASKS = 任务目录 (默认 ~/.claude/tasks)
set -uo pipefail
TASKS="${TASKS:-$HOME/.claude/tasks}"
die(){ echo "fanout-task: $*" >&2; exit 2; }
ts(){  TZ="${FANOUT_TZ:-Asia/Shanghai}" date '+%Y-%m-%d %H:%M'; }
day(){ TZ="${FANOUT_TZ:-Asia/Shanghai}" date '+%Y-%m-%d'; }
sed_inplace(){ # 跨 GNU/BSD sed
  if sed --version >/dev/null 2>&1; then sed -i -E "$1" "$2"; else sed -i '' -E "$1" "$2"; fi
}

cmd_new(){
  local title="${1:-}" prio="${2:-P1}"
  [ -n "$title" ] || die "用法: new <title> [P0|P1|P2]"
  mkdir -p "$TASKS"
  local d n=1 f; d="$(day)"
  while :; do f="$TASKS/TASK-$d-$(printf '%03d' "$n").md"; [ -e "$f" ] || break; n=$((n+1)); done
  {
    echo "# TASK-$d-$(printf '%03d' "$n"): $title"
    echo "Status: IN_PROGRESS"
    echo "Priority: $prio"
    echo "Created: $(ts)"
    echo "Completed: -"
    echo ""
    echo "## 需求"
    echo "$title"
    echo ""
    echo "## 子任务"
    echo "- [ ] (task1) — <scope> (Implementer: cc-xxx, file: ...)"
    echo "- [ ] Final Review (Reviewer: coder)"
    echo ""
    echo "## 协作矩阵"
    echo "| Task | Implementer | Reviewer | Fixer |"
    echo "|---|---|---|---|"
    echo "| 1 | cc-xxx | coder | 我 Edit patch |"
    echo ""
    echo "## 输出文件"
    echo "- ..."
    echo ""
    echo "## 执行日志"
  } > "$f"
  echo "$f"
}

cmd_log(){
  local f="${1:-}"; shift || true
  [ -n "$f" ] && [ -f "$f" ] || die "无 TASK 文件: ${f:-(空)}"
  printf -- '- [%s] %s\n' "$(ts)" "$*" >> "$f"
  echo "logged → $f"
}

cmd_done(){
  local f="${1:-}"
  [ -n "$f" ] && [ -f "$f" ] || die "无 TASK 文件: ${f:-(空)}"
  sed_inplace "s/^Status: .*/Status: DONE/" "$f"
  sed_inplace "s/^Completed: .*/Completed: $(ts)/" "$f"
  echo "DONE → $f"
}

sub="${1:-}"; shift || true
case "$sub" in
  new)  cmd_new  "$@";;
  log)  cmd_log  "$@";;
  done) cmd_done "$@";;
  ''|-h|--help) sed -n '2,9p' "$0";;
  *) die "未知子命令 '$sub' (new|log|done)";;
esac
