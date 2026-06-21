#!/usr/bin/env bash
# fanout-workspace.sh — Workspace 上下文隔离 (借鉴 Zleap-Agent)
# 核心: 别给(小)模型喂全部 context —— 按"工位"只给该任务该看的。
# Context = System Prompt + Workspace Prompt + Tools + Memory + History
#   list                        列出 workspaces
#   show  <name>                打印 workspace 原始字段
#   model <name>                解析模型 (models: @bench:<type> 走 allocation)
#   context <name> [--task T]   组装并打印分层上下文 (喂给该工位 agent 的 prompt 前缀)
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WSDIR="${FANOUT_WORKSPACES:-$HERE/workspaces}"
die(){ echo "fanout-workspace: $*" >&2; exit 2; }
wsfile(){ printf '%s/%s.workspace' "$WSDIR" "$1"; }
field(){ sed -n "s/^$1:[[:space:]]*//p" "$2" | head -1; }

resolve_models(){  # @bench:<type> → 走 allocation; 否则原样
  case "$1" in
    @bench:*) bash "$HERE/fanout-allocate.sh" "${1#@bench:}" 2>/dev/null;;
    *) printf '%s' "$1";;
  esac
}

cmd_list(){
  local f n
  for f in "$WSDIR"/*.workspace; do
    [ -e "$f" ] || continue
    n="$(basename "$f" .workspace)"
    printf '  %-10s %s\n' "$n" "$(field prompt "$f" | cut -c1-44)"
  done
}

cmd_show(){ local f; f="$(wsfile "${1:-}")"; [ -f "$f" ] || die "无 workspace '${1:-}' (见 list)"; cat "$f"; }

cmd_model(){ local f; f="$(wsfile "${1:-}")"; [ -f "$f" ] || die "无 workspace '${1:-}'"; resolve_models "$(field models "$f")"; }

cmd_context(){
  local name="${1:-}"; shift || true
  local f; f="$(wsfile "$name")"; [ -f "$f" ] || die "无 workspace '$name' (见 list)"
  local task=""
  while [ "$#" -gt 0 ]; do case "$1" in --task) task="${2:-}"; shift 2;; *) die "未知参数 '$1'";; esac; done
  local models; models="$(resolve_models "$(field models "$f")")"

  echo "## Context — workspace: $name"
  echo ""
  echo "### System Prompt"
  [ -f "$WSDIR/_system.md" ] && cat "$WSDIR/_system.md"
  echo ""
  echo "### Workspace Prompt"
  field prompt "$f"
  echo ""
  echo "### Tools"
  printf '%s  (仅本工位启用, 其余不暴露)\n' "$(field tools "$f" | tr ',' ' ')"
  local sk; sk="$(field skills "$f")"
  [ -n "$sk" ] && printf 'skills: %s\n' "$sk"
  echo ""
  echo "### Memory"
  printf '范围: %s  (只取该范围相关记忆, 非全量归档)\n' "$(field memory "$f")"
  # Experience memory: 注入该工位累积的可复用方法 (借鉴 Zleap)
  local exp; exp="$(bash "$HERE/fanout-experience.sh" recall "$name" --limit 3 2>/dev/null || true)"
  [ -n "$exp" ] && { echo ""; printf '%s\n' "$exp"; }
  echo ""
  echo "### History"
  echo "最近若干轮对话 + 关键执行轨迹 (非完整 transcript)"
  [ -n "$task" ] && { echo ""; echo "### Task"; printf '%s\n' "$task"; }
  [ -n "$models" ] && { echo ""; printf '> 建议模型(bench): %s\n' "$models"; }
}

sub="${1:-}"; shift || true
case "$sub" in
  list)    cmd_list;;
  show)    cmd_show    "$@";;
  model)   cmd_model   "$@";;
  context) cmd_context "$@";;
  ''|-h|--help) sed -n '2,12p' "$0";;
  *) die "未知子命令 '$sub' (list|show|model|context)";;
esac
