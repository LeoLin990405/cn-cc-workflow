#!/usr/bin/env bash
# fuguectl-template.sh — thin shell bridge to the TypeScript prompt template renderer
#   usage: fuguectl-template.sh <name> [--set KEY=VALUE ...]
#   {{KEY}} not --set is left verbatim (for Claude to fill)
#   env: FUGUE_ENGINE_CLI overrides the built engine CLI path
set -uo pipefail
# shellcheck source=/dev/null
. "$(dirname "${BASH_SOURCE[0]}")/fuguectl-lib.sh"

fx_run_engine template "$@"
