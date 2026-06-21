#!/usr/bin/env bash
# fanout-cache.sh — fan-out 结果缓存 + fan-in barrier
#
# 逻辑契约: Claude Desktop(planner)本轮发出 N 个任务, 就必须收回 N 个 (全部落缓存)
#   才能进入下一轮。每个 agent 结果先进缓存, integrator 只从缓存读。
#
# 缓存布局 (${FANOUT_CACHE:-<repo>/.fanout-cache}/round-<N>/):
#   manifest.tsv        init 后不可变: 每行 "task_id<TAB>agent" = 本轮声明的 N 个任务
#   <task_id>.result    put 落进来的 agent 产物 (atomic)
#   <task_id>.status    "done" | "fail" (marker, 并发安全: 每任务只碰自己的文件)
#   <task_id>.reason    fail 原因 (可选)
#
# 子命令:
#   init    <round> <task_id:agent> [...]   声明本轮 N 个任务 (重置该 round)
#   put     <round> <task_id> <file>        存某任务结果 + 标 done (task 必须在 manifest)
#   fail    <round> <task_id> [reason]      标某任务失败 (也算"已返回")
#   status  <round>                         打印 done/fail/pending 计数
#   barrier <round> [--wait [secs]] [--require-success]
#                                           N 全部 terminal 才 exit 0; 否则 exit 1
#   collect <round>                         输出 done 任务的 result 路径 (给 integrator)
#   list    <round>                         明细
#   resume  <round>                         打印未返回的 task_id<TAB>agent (中断后只重派这些)
#
# 退出码: 0 成功 / 1 barrier 未达或失败 / 2 用法错
set -uo pipefail

CACHE_ROOT="${FANOUT_CACHE:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)/.fanout-cache}"

die()  { echo "fanout-cache: $*" >&2; exit 2; }
rdir() { printf '%s/round-%s' "$CACHE_ROOT" "$1"; }

_manifest() { cat "$(rdir "$1")/manifest.tsv" 2>/dev/null; }
_ids()      { _manifest "$1" | cut -f1; }
_total()    { _manifest "$1" | grep -c . ; }
_terminal() { # 已 terminal(done|fail) 的任务数
  local r="$1" n=0 id d; d="$(rdir "$1")"
  while IFS= read -r id; do [ -n "$id" ] && [ -f "$d/$id.status" ] && n=$((n+1)); done < <(_ids "$r")
  echo "$n"
}

cmd_init() {
  local round="$1"; shift || true
  [ -n "${round:-}" ] && [ "$#" -gt 0 ] || die "用法: init <round> <task_id:agent> [...]"
  local d; d="$(rdir "$round")"
  rm -rf "$d"; mkdir -p "$d"
  : > "$d/manifest.tsv"
  date +%s > "$d/.started"   # 计时基准
  local pair id agent
  for pair in "$@"; do
    id="${pair%%:*}"; agent="${pair#*:}"
    [ -n "$id" ] && [ "$id" != "$pair" ] || die "任务格式应为 task_id:agent, 收到 '$pair'"
    printf '%s\t%s\n' "$id" "$agent" >> "$d/manifest.tsv"
  done
  echo "✓ round-$round 声明 $# 个任务: $*"
}

cmd_put() {
  local round="$1" id="$2" file="$3"
  [ -n "${round:-}" ] && [ -n "${id:-}" ] && [ -n "${file:-}" ] || die "用法: put <round> <task_id> <file>"
  local d; d="$(rdir "$round")"
  [ -f "$d/manifest.tsv" ] || die "round-$round 未 init"
  _ids "$round" | grep -qxF "$id" || die "任务 '$id' 不在 manifest (只接受本轮声明的任务)"
  [ -f "$file" ] || die "结果文件不存在: $file"
  cp "$file" "$d/.$id.result.tmp" && mv -f "$d/.$id.result.tmp" "$d/$id.result"
  printf 'done\n' > "$d/$id.status"; date +%s > "$d/$id.at"
  echo "✓ cached $id ($(wc -c <"$d/$id.result" | tr -d ' ') bytes) [$(_terminal "$round")/$(_total "$round")]"
}

cmd_fail() {
  local round="$1" id="$2"; shift 2 || true
  [ -n "${round:-}" ] && [ -n "${id:-}" ] || die "用法: fail <round> <task_id> [reason]"
  local d; d="$(rdir "$round")"
  [ -f "$d/manifest.tsv" ] || die "round-$round 未 init"
  _ids "$round" | grep -qxF "$id" || die "任务 '$id' 不在 manifest"
  printf 'fail\n' > "$d/$id.status"; date +%s > "$d/$id.at"
  [ "$#" -gt 0 ] && printf '%s\n' "$*" > "$d/$id.reason"
  echo "✗ failed $id: ${*:-(no reason)} [$(_terminal "$round")/$(_total "$round")]"
}

cmd_status() {
  local round="$1"; [ -n "${round:-}" ] || die "用法: status <round>"
  local d; d="$(rdir "$round")"; [ -f "$d/manifest.tsv" ] || die "round-$round 未 init"
  local total nd fail id
  total="$(_total "$round")"; nd=0; fail=0
  while IFS= read -r id; do
    [ -n "$id" ] || continue
    case "$(cat "$d/$id.status" 2>/dev/null)" in
      done) nd=$((nd+1));; fail) fail=$((fail+1));;
    esac
  done < <(_ids "$round")
  echo "round-$round: total=$total done=$nd fail=$fail pending=$((total-nd-fail))"
}

cmd_barrier() {
  local round="$1"; shift || true
  [ -n "${round:-}" ] || die "用法: barrier <round> [--wait [secs]] [--require-success]"
  local wait=0 timeout=300 require_success=0
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --wait) wait=1; case "${2:-}" in ''|--*) ;; *) timeout="$2"; shift;; esac;;
      --require-success) require_success=1;;
      *) die "未知参数 $1";;
    esac; shift
  done
  local d; d="$(rdir "$round")"; [ -f "$d/manifest.tsv" ] || die "round-$round 未 init"

  local total elapsed=0
  total="$(_total "$round")"
  [ "$total" -gt 0 ] || die "round-$round manifest 为空"
  while :; do
    local term; term="$(_terminal "$round")"
    if [ "$term" -ge "$total" ]; then
      if [ "$require_success" -eq 1 ]; then
        local nfail; nfail="$(grep -rl '^fail' "$d"/*.status 2>/dev/null | wc -l | tr -d ' ')"
        if [ "$nfail" -gt 0 ]; then
          echo "✗ barrier round-$round: $total/$total 已返回, 但 $nfail 个失败 (--require-success)"; return 1
        fi
      fi
      echo "✓ barrier round-$round: $total/$total 全部返回 → 可进入下一轮"; return 0
    fi
    if [ "$wait" -eq 0 ]; then
      echo "✗ barrier round-$round: 仅 $term/$total 返回, 未达 → 不许进入下一轮"; cmd_status "$round" >&2; return 1
    fi
    [ "$elapsed" -ge "$timeout" ] && { echo "✗ barrier round-$round: 等待 ${timeout}s 超时, $term/$total" >&2; return 1; }
    sleep 3; elapsed=$((elapsed+3))
  done
}

cmd_collect() {
  local round="$1"; [ -n "${round:-}" ] || die "用法: collect <round>"
  local d id; d="$(rdir "$round")"; [ -f "$d/manifest.tsv" ] || die "round-$round 未 init"
  while IFS= read -r id; do
    [ -n "$id" ] && [ -f "$d/$id.result" ] && printf '%s\n' "$d/$id.result"
  done < <(_ids "$round")
}

cmd_list() {
  local round="$1"; [ -n "${round:-}" ] || die "用法: list <round>"
  local d id agent st; d="$(rdir "$round")"; [ -f "$d/manifest.tsv" ] || die "round-$round 未 init"
  while IFS=$'\t' read -r id agent; do
    [ -n "$id" ] || continue
    st="$(cat "$d/$id.status" 2>/dev/null || echo pending)"
    printf '  %-22s %-14s %s\n' "$id" "$agent" "$st"
  done < "$d/manifest.tsv"
}

# resume: 打印未 terminal(未返回) 的 task_id<TAB>agent —— 中断后只重派这些, 不重跑全部
cmd_resume() {
  local round="$1"; [ -n "${round:-}" ] || die "用法: resume <round>"
  local d id agent; d="$(rdir "$round")"; [ -f "$d/manifest.tsv" ] || die "round-$round 未 init"
  while IFS=$'\t' read -r id agent; do
    [ -n "$id" ] || continue
    [ -f "$d/$id.status" ] || printf '%s\t%s\n' "$id" "$agent"
  done < "$d/manifest.tsv"
}

sub="${1:-}"; shift || true
case "$sub" in
  init)    cmd_init    "$@";;
  put)     cmd_put     "$@";;
  fail)    cmd_fail    "$@";;
  status)  cmd_status  "$@";;
  barrier) cmd_barrier "$@";;
  collect) cmd_collect "$@";;
  list)    cmd_list    "$@";;
  resume)  cmd_resume  "$@";;
  ''|-h|--help) sed -n '2,34p' "$0";;
  *) die "未知子命令 '$sub' (init|put|fail|status|barrier|collect|list|resume)";;
esac
