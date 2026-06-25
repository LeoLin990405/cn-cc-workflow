#!/usr/bin/env bash
# fuguectl-goal.sh — thin shell bridge to the TypeScript goal commands
#
# Wraps loop v2 + bench allocation + cache in one declarative goal. spec is key: value lines:
#   outcome:  one-line goal
#   gate:     one runnable objective acceptance command (e.g. pytest -q && npm run build)
#   rubric:   focus areas for Codex subjective review
#   rounds:   loop round cap
#   allocate: auto | manual
#
#   template          print spec template
#   show  <spec>      parse and display spec fields
#   check <spec>      run gate command: met = exit 0, else 1 (Phase 5 loop objective acceptance gate)
#   env: FUGUE_ENGINE_CLI overrides the built engine CLI path
set -uo pipefail
# shellcheck source=/dev/null
. "$(dirname "${BASH_SOURCE[0]}")/fuguectl-lib.sh"

sub="${1:-}"; shift || true
case "$sub" in
  template|show|check) fx_run_engine goal "$sub" "$@";;
  ''|-h|--help) sed -n '2,18p' "$0";;
  *) die "unknown subcommand '$sub' (template|show|check)";;
esac
