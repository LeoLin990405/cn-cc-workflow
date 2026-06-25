#!/usr/bin/env bash
# fuguectl-workspace.sh — thin shell bridge to the TypeScript Workspace commands
# Core: don't feed a (small) model the whole context — per "station", give only what that task should see.
# Context = System Prompt + Workspace Prompt + Tools + Memory + History
#   list                        list workspaces
#   show  <name>                print workspace raw fields
#   model <name>                resolve model (models: @bench:<type> goes through allocation)
#   context <name> [--task T]   assemble and print layered context (prompt prefix fed to this station's agent)
#   env: FUGUE_ENGINE_CLI overrides the built engine CLI path
set -uo pipefail
# shellcheck source=/dev/null
. "$(dirname "${BASH_SOURCE[0]}")/fuguectl-lib.sh"

sub="${1:-}"; shift || true
case "$sub" in
  list|show|model|context) fx_run_engine workspace "$sub" "$@";;
  ''|-h|--help) sed -n '2,12p' "$0";;
  *) die "unknown subcommand '$sub' (list|show|model|context)";;
esac
