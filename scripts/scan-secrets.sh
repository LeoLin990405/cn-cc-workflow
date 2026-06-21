#!/usr/bin/env bash
# scan-secrets.sh — 仓库密钥泄漏闸门 (本机 / CI / pre-commit 共用)
# 命中任何疑似明文密钥即 exit 1。allowlist: *.example 里的 <PLACEHOLDER> 占位 + 合法署名。
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT" || exit 2
fail=0

# 扫描范围: git 跟踪的文件 (回退到 find), 排除 .git / node_modules
if git rev-parse --git-dir >/dev/null 2>&1; then
  mapfile -t FILES < <(git ls-files)
else
  mapfile -t FILES < <(find . -type f -not -path './.git/*' -not -path '*/node_modules/*' | sed 's|^\./||')
fi

# ── 1) 明文密钥指纹 ──────────────────────────────────────────
# sk-... (deepseek/kimi/minimax/openai) | tp-... (mimo) | zhipu hex32.b64-16
SECRET_RE='sk-[A-Za-z0-9_-]{20,}|tp-[a-z0-9]{30,}|[0-9a-f]{32}\.[A-Za-z0-9]{16}'
for f in "${FILES[@]}"; do
  [ -f "$f" ] || continue
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    echo "  ✗ 疑似密钥  $f: $line" ; fail=1
  done < <(grep -nE "$SECRET_RE" "$f" 2>/dev/null)
done

# ── 2) ccb.config(.example) 里 key= 必须是 <PLACEHOLDER> ──────
for f in "${FILES[@]}"; do
  case "$f" in *ccb.config*) ;; *) continue ;; esac
  while IFS= read -r line; do
    content="${line#*:}"                             # 剥掉 grep -n 的 "行号:" 前缀
    # 取等号右侧的引号值, 必须形如 <XXX>
    val="$(printf '%s' "$content" | sed -E 's/^[[:space:]]*key[[:space:]]*=[[:space:]]*"?([^"]*)"?.*/\1/')"
    case "$val" in
      '<'*'>') : ;;                                  # ok: 占位
      '') : ;;                                        # 空也放过
      *) echo "  ✗ key 非占位  $f: $line"; fail=1 ;;
    esac
  done < <(grep -nE '^[[:space:]]*key[[:space:]]*=' "$f" 2>/dev/null)
done

if [ "$fail" -eq 0 ]; then
  echo "✓ scan-secrets: 0 命中 (${#FILES[@]} 文件)"
else
  echo "✗ scan-secrets: 发现疑似密钥, 阻断。"
fi
exit "$fail"
