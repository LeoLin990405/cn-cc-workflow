#!/usr/bin/env bash
# fuguectl-dispatch.sh — thin shell bridge to the TypeScript harness dispatcher.
#   fuguectl-dispatch.sh <target> [--harness fugue-cc|codex|opencode] [--workspace <ws>] \
#       (--template <name> [--set K=V ...] | --prompt-file <f>) [--task <file>]
#   --task-type T  append (T, agent) into alloc ledger → later `allocate feed --from-ledger`
#   --skills a,b   inject selected skills into that agent context
#   env: FUGUE_CC_BIN / FUGUE_CODEX / FUGUE_OPENCODE / FUGUE_ALLOCATION_LEDGER / FUGUE_ENGINE_CLI
set -uo pipefail
# shellcheck source=/dev/null
. "$(dirname "${BASH_SOURCE[0]}")/fuguectl-lib.sh"

case "${1:-}" in
  -h|--help) sed -n '2,8p' "$0";;
  *) fx_run_engine dispatch "$@";;
esac
