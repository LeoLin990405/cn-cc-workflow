#!/usr/bin/env bash
# check-shell.sh — 启动器/脚本的语法 + 静态检查 (本机 / CI / pre-commit 共用)
#   1) bash -n 语法检查 (永远跑)
#   2) shellcheck 静态检查 (装了才跑, 走 .shellcheckrc; CI 里保证装)
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT" || exit 2

# 收集所有 bash 脚本: 启动器(无扩展名,靠 shebang) + *.sh
mapfile -t SCRIPTS < <(
  { ls backends/bin/*-code backends/bin/cc-models backends/bin/cc-sync orchestration/fanout/fanout 2>/dev/null
    find backends scripts orchestration -name '*.sh' 2>/dev/null
  } | sort -u
)

fail=0

echo "── bash -n 语法 (${#SCRIPTS[@]} 脚本) ──"
for f in "${SCRIPTS[@]}"; do
  if bash -n "$f" 2>/dev/null; then :; else echo "  ✗ syntax: $f"; fail=1; fi
done
[ "$fail" -eq 0 ] && echo "  ✓ 全过"

if command -v shellcheck >/dev/null 2>&1; then
  echo "── shellcheck -S warning (走 .shellcheckrc) ──"
  if shellcheck -S warning "${SCRIPTS[@]}"; then
    echo "  ✓ 0 warning"
  else
    echo "  ✗ shellcheck 有发现"; fail=1
  fi
else
  echo "── shellcheck 未安装, 跳过 (CI 会跑) ──"
fi

exit "$fail"
