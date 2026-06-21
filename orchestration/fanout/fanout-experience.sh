#!/usr/bin/env bash
# fanout-experience.sh — Experience memory (借鉴 Zleap-Agent)
# 完成的任务 → 抽可复用方法 → **脱敏** → 按 workspace 分桶存 → 未来同类任务注入 context。
# (Zleap 三分记忆里的 Experience: 复用方法, 脱敏后归 workspace。本仓文件实现, 非 DB。)
#   add  <ws> "<title>" [--from <file>]   存一条经验 (body 从 --from 或 stdin; 脱敏不过则拒)
#   list [<ws>]                           列经验
#   recall <ws> [--query kw] [--limit N]  取该 ws 相关经验 (默认 limit 3, 给 context 注入)
#   show <ws> <slug>                      打印一条
#   env: FANOUT_EXPERIENCE (默认 ${FANOUT_STATE:-~/.config/fanout}/experience)
set -uo pipefail
STORE="${FANOUT_EXPERIENCE:-${FANOUT_STATE:-$HOME/.config/fanout}/experience}"
die(){ echo "fanout-experience: $*" >&2; exit 2; }
# 脱敏指纹 (同 scan-secrets): 明文 key 不许进经验库
SECRET_RE='sk-[A-Za-z0-9_-]{20,}|tp-[a-z0-9]{30,}|[0-9a-f]{32}\.[A-Za-z0-9]{16}'
slugify(){ printf '%s' "$1" | tr ' /' '--' | tr -d '"'\''`'; }   # 删引号反引号, 空格/斜杠→-

cmd_add(){
  local ws="${1:-}" title="${2:-}"; shift 2 2>/dev/null || true
  [ -n "$ws" ] && [ -n "$title" ] || die "用法: add <ws> \"<title>\" [--from <file>]"
  local src=""
  while [ "$#" -gt 0 ]; do case "$1" in --from) src="${2:-}"; shift 2;; *) die "未知参数 '$1'";; esac; done
  local body
  if [ -n "$src" ]; then [ -f "$src" ] || die "无 --from 文件 $src"; body="$(cat "$src")"
  else body="$(cat)"; fi   # stdin
  [ -n "$body" ] || die "经验 body 为空"
  # 脱敏闸门
  if printf '%s' "$body" | grep -qE "$SECRET_RE"; then die "body 含疑似密钥, 拒绝入库 (先脱敏)"; fi
  local d="$STORE/$ws"; mkdir -p "$d"
  local slug f; slug="$(slugify "$title")"; f="$d/$slug.md"
  {
    echo "---"; echo "workspace: $ws"; echo "title: $title"; echo "created: $(date +%s)"; echo "---"
    printf '%s\n' "$body"
  } > "$f"
  echo "✓ 经验入库: $f"
}

cmd_list(){
  local ws="${1:-}"
  local base="$STORE"; [ -n "$ws" ] && base="$STORE/$ws"
  [ -d "$base" ] || { echo "(暂无经验)"; return 0; }
  local f
  find "$base" -name '*.md' 2>/dev/null | sort | while read -r f; do
    printf '  %-12s %s\n' "$(basename "$(dirname "$f")")" "$(sed -n 's/^title: //p' "$f" | head -1)"
  done
}

cmd_recall(){
  local ws="${1:-}"; shift || true
  [ -n "$ws" ] || die "用法: recall <ws> [--query kw] [--limit N]"
  local query="" limit=3
  while [ "$#" -gt 0 ]; do
    case "$1" in --query) query="${2:-}"; shift 2;; --limit) limit="${2:-3}"; shift 2;; *) die "未知参数 '$1'";; esac
  done
  local d="$STORE/$ws"; [ -d "$d" ] || return 0   # 无经验 = 空输出
  # 候选: 该 ws 全部, 按 mtime 新→旧; 有 query 则先按内容过滤
  local files=() f
  while IFS= read -r f; do files+=("$f"); done < <(
    if [ -n "$query" ]; then grep -rlF "$query" "$d" 2>/dev/null; else find "$d" -name '*.md' 2>/dev/null; fi \
      | while read -r x; do printf '%s\t%s\n' "$(sed -n 's/^created: //p' "$x" | head -1)" "$x"; done \
      | sort -rn | cut -f2-)
  local n=0
  for f in ${files[@]+"${files[@]}"}; do
    [ "$n" -ge "$limit" ] && break
    printf '【经验】%s\n' "$(sed -n 's/^title: //p' "$f" | head -1)"
    sed '1,/^---$/d; /^---$/d' "$f" 2>/dev/null | sed '/^workspace:/d;/^title:/d;/^created:/d'
    echo ""
    n=$((n+1))
  done
}

cmd_show(){
  local ws="${1:-}" slug="${2:-}"; [ -n "$ws" ] && [ -n "$slug" ] || die "用法: show <ws> <slug>"
  local f="$STORE/$ws/$slug.md"; [ -f "$f" ] || die "无经验 $ws/$slug"
  cat "$f"
}

sub="${1:-}"; shift || true
case "$sub" in
  add)    cmd_add    "$@";;
  list)   cmd_list   "$@";;
  recall) cmd_recall "$@";;
  show)   cmd_show   "$@";;
  ''|-h|--help) sed -n '2,13p' "$0";;
  *) die "未知子命令 '$sub' (add|list|recall|show)";;
esac
