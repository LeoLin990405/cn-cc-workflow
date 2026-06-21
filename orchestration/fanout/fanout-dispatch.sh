#!/usr/bin/env bash
# fanout-dispatch.sh — 取/渲 prompt → 派给 agent (harness 无关) → 记 TASK 日志
#   fanout-dispatch.sh <target> [--harness ccb|codex|opencode] [--workspace <ws>] \
#       (--template <name> [--set K=V ...] | --prompt-file <f>) [--task <file>]
#   --harness 选执行器: ccb(默认, Claude Code cc-* 分身) / codex(codex exec) / opencode(opencode run)
#     <target> 含义随 harness: ccb=ccb agent(cc-deepseek) / codex=model(gpt-5.5) / opencode=provider/model
#   --workspace 前缀注入该工位分层 context (Zleap 式: 只喂该看的)
#   env: FANOUT_CCB / FANOUT_CODEX / FANOUT_OPENCODE (默认 ccb/codex/opencode; 测试可 stub)
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CCB="${FANOUT_CCB:-ccb}"
die(){ echo "fanout-dispatch: $*" >&2; exit 2; }

agent="${1:-}"; shift || true
[ -n "$agent" ] || die "用法: <agent> (--template <name> [--set K=V] | --prompt-file <f>) [--task <file>]"

tpl=""; pfile=""; task=""; ws=""; harness="ccb"; sets=()
while [ "$#" -gt 0 ]; do
  case "$1" in
    --template)    tpl="${2:-}"; shift 2;;
    --set)         sets+=("--set" "${2:-}"); shift 2;;
    --prompt-file) pfile="${2:-}"; shift 2;;
    --workspace)   ws="${2:-}"; shift 2;;
    --harness)     harness="${2:-}"; shift 2;;
    --task)        task="${2:-}"; shift 2;;
    *) die "未知参数 '$1'";;
  esac
done

# workspace context 前缀 (借鉴 Zleap: 只喂该工位该看的分层 context)
ctx=""
[ -n "$ws" ] && ctx="$(bash "$HERE/fanout-workspace.sh" context "$ws")
"

# 取 prompt body
if [ -n "$pfile" ]; then
  [ -f "$pfile" ] || die "无 prompt 文件 $pfile"; body="$(cat "$pfile")"
elif [ -n "$tpl" ]; then
  body="$(bash "$HERE/fanout-template.sh" "$tpl" ${sets[@]+"${sets[@]}"})"
elif [ -n "$ws" ]; then
  body=""   # 仅 workspace context 即作 prompt
else die "需要 --template <name> / --prompt-file <f> / --workspace <name>"; fi
prompt="${ctx}${body}"

# 派活 (harness 无关)：<target> 含义随 harness 变
case "$harness" in
  ccb)      printf '%s\n' "$prompt" | "$CCB" ask "$agent" --compact; rc=$? ;;   # Claude Code cc-* 分身
  codex)    "${FANOUT_CODEX:-codex}" exec --model "$agent" "$prompt"; rc=$? ;;    # codex exec, target=model
  opencode) "${FANOUT_OPENCODE:-opencode}" run -m "$agent" "$prompt"; rc=$? ;;    # opencode run, target=provider/model
  *) die "未知 harness '$harness' (ccb|codex|opencode)" ;;
esac

# 记 TASK 日志 (可选)
if [ -n "$task" ] && [ -f "$task" ]; then
  printf -- '- [%s] dispatch → %s [%s] (rc=%s)\n' "$(TZ=Asia/Shanghai date '+%Y-%m-%d %H:%M')" "$agent" "$harness" "$rc" >> "$task"
fi
exit "$rc"
