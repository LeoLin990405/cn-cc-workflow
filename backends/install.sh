#!/usr/bin/env bash
set -euo pipefail

HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
exec node "$HERE/../scripts/run-ts.mjs" "$HERE/install.ts" "$@"
