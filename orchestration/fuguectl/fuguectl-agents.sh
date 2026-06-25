#!/usr/bin/env bash
# fuguectl-agents.sh — thin shell bridge to the TypeScript Agent Runtime Registry
#
# The registry parser, schema checks, formatting, and coordinator semantics live
# in the TypeScript engine. This file stays deliberately small: it preserves the
# stable fuguectl shell entry while delegating real work to `fugue agent-registry`.
#
#   template               print a starter registry JSON
#   validate <file>        validate the registry schema
#   list <file>            print id<TAB>harness<TAB>target<TAB>roles
#   resolve <file> <id>    print resolved fields for one logical agent id
#   env: FUGUE_ENGINE_CLI overrides the built engine CLI path
set -uo pipefail
# shellcheck source=/dev/null
. "$(dirname "${BASH_SOURCE[0]}")/fuguectl-lib.sh"

sub="${1:-}"; shift || true
case "$sub" in
  template|validate|list|resolve) fx_run_engine agent-registry "$sub" "$@";;
  ''|-h|--help) sed -n '2,14p' "$0";;
  *) die "unknown subcommand '$sub' (template|validate|list|resolve)";;
esac
