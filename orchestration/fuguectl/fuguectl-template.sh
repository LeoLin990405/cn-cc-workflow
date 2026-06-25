#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
name="${BASH_SOURCE[0]##*/}"
exec "$HERE/${name%.sh}" "$@"
