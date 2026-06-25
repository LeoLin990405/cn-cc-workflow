#!/usr/bin/env bash
# fuguectl-task.sh — thin shell bridge to the TypeScript TASK commands
#
#   new  "<title>" [P0|P1|P2]     create TASK-<date>-<NNN>.md under $TASKS, print path
#   log  <task-file> "<message>"  append timestamped log to the "Log" section
#   done <task-file>              Status: DONE + Completed time
#   env: TASKS = task directory (default ~/.claude/tasks)
#   env: FUGUE_ENGINE_CLI overrides the built engine CLI path
set -uo pipefail
# shellcheck source=/dev/null
. "$(dirname "${BASH_SOURCE[0]}")/fuguectl-lib.sh"

cmd_new(){
  local title="${1:-}" prio=""
  shift || true
  [ -n "$title" ] || die "usage: new <title> [P0|P1|P2]"
  case "$#" in
    0) fx_run_engine task new "$title";;
    1) fx_run_engine task new "$title" --priority "$1";;
    2)
      [ "${1:-}" = "--priority" ] || die "usage: new <title> [P0|P1|P2]"
      prio="${2:-}"
      fx_run_engine task new "$title" --priority "$prio";;
    *) die "usage: new <title> [P0|P1|P2]";;
  esac
}

cmd_log(){
  local f="${1:-}"; shift || true
  [ -n "$f" ] || die "usage: log <task-file> <message>"
  [ "$#" -gt 0 ] || die "usage: log <task-file> <message>"
  fx_run_engine task log "$f" "$*"
}

cmd_done(){
  local f="${1:-}"
  [ -n "$f" ] || die "usage: done <task-file>"
  fx_run_engine task "done" "$f"
}

sub="${1:-}"; shift || true
case "$sub" in
  new)  cmd_new  "$@";;
  log)  cmd_log  "$@";;
  done) cmd_done "$@";;
  ''|-h|--help) sed -n '2,9p' "$0";;
  *) die "unknown subcommand '$sub' (new|log|done)";;
esac
