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

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TBL="${FUGUE_ALLOCATION:-$HERE/allocation.tsv}"
STATS="${FUGUE_ALLOCATION_STATS:-${FUGUE_STATE:-${HOME:-$HERE}/.config/fugue}/allocation-stats.tsv}"
LEDGER="${FUGUE_ALLOCATION_LEDGER:-${FUGUE_STATE:-${HOME:-$HERE}/.config/fugue}/alloc-ledger.tsv}"
KAPPA="${FUGUE_ALLOCATE_KAPPA:-4}"

case "${1:-}" in
  ''|-h|--help) sed -n '2,13p' "$0";;
  *) fx_run_engine allocate --table "$TBL" --stats "$STATS" --ledger "$LEDGER" --kappa "$KAPPA" "$@";;
esac
