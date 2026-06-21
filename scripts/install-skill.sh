#!/usr/bin/env bash
# install-skill.sh — 把 fanout 装成 Claude Code skill (~/.claude/skills/fanout)
# 已存在则先备份(绝不静默覆盖)。装完重开 Claude Code 会话即可 /fanout 唤醒。
#   env: CLAUDE_SKILLS_DIR (默认 ~/.claude/skills) — 装到别处/测试用
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="$ROOT/orchestration/fanout"
DEST="${CLAUDE_SKILLS_DIR:-$HOME/.claude/skills}/fanout"

[ -f "$SRC/SKILL.md" ] || { echo "✗ 找不到 $SRC/SKILL.md" >&2; exit 1; }
mkdir -p "$(dirname "$DEST")"

if [ -e "$DEST" ]; then
  bak="$DEST.bak.$(date +%Y%m%d-%H%M%S)"
  mv "$DEST" "$bak"
  echo "ℹ 已备份现有 skill → $bak"
fi

cp -R "$SRC" "$DEST"
chmod +x "$DEST/fanout" 2>/dev/null || true
chmod +x "$DEST"/*.sh 2>/dev/null || true

echo "✓ fanout skill 已装到 $DEST"
echo "  下一步：重开一个 Claude Code 会话 → 输入 /fanout 或说「用 fanout 做 X / 多 agent 协作」"
echo "  自检：$DEST/fanout selftest"
echo "  注：真 API key 不随 skill 走，仍放 ~/.config/cc-model-secrets.env"
