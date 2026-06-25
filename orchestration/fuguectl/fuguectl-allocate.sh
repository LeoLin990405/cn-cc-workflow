#!/usr/bin/env bash
# fuguectl-allocate.sh — thin shell bridge to the TypeScript adaptive allocator.
#
#   <task-type> [--top] [--sample]
#   list
#   record <task-type> <agent> <ok|fail>
#   feed type:agent:result [...]
#   feed --from-ledger --result ok|fail [--fail a,b] [--ok a,b] [--keep]
#   stats <task-type>
#   reset [<task-type>]
#   decay [--gamma G] [--type T]
#   env: FUGUE_ALLOCATION, FUGUE_ALLOCATION_STATS, FUGUE_ALLOCATION_LEDGER,
#        FUGUE_ALLOCATE_KAPPA, FUGUE_ALLOCATE_SEED, FUGUE_STATE, FUGUE_ENGINE_CLI
set -uo pipefail
# shellcheck source=/dev/null
. "$(dirname "${BASH_SOURCE[0]}")/fuguectl-lib.sh"

case "${1:-}" in
  ''|-h|--help) sed -n '2,13p' "$0";;
  *) fx_run_engine allocate "$@";;
esac
