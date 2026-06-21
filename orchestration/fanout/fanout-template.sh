#!/usr/bin/env bash
# fanout-template.sh — 渲染 prompt 模板 (templates/<name>.md), 字面替换 {{KEY}}
#   用法: fanout-template.sh <name> [--set KEY=VALUE ...]
#   未 --set 的 {{KEY}} 原样保留 (留给 Claude 填)
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TPLDIR="$HERE/templates"
die(){ echo "fanout-template: $*" >&2; exit 2; }

name="${1:-}"; shift || true
[ -n "$name" ] || die "用法: <name> [--set KEY=VALUE ...]  (可用: $(ls "$TPLDIR" 2>/dev/null | sed 's/\.md$//' | tr '\n' ' '))"
f="$TPLDIR/$name.md"
[ -f "$f" ] || die "无模板 '$name' (在 $TPLDIR)"

content="$(cat "$f")"
while [ "$#" -gt 0 ]; do
  case "$1" in
    --set)
      kv="${2:-}"; [ -n "$kv" ] || die "--set 缺 KEY=VALUE"; shift 2
      key="${kv%%=*}"; val="${kv#*=}"
      [ "$key" != "$kv" ] || die "--set 格式应为 KEY=VALUE, 收到 '$kv'"
      content="${content//"{{$key}}"/$val}"   # bash 字面替换 (引号使 pattern 字面化)
      ;;
    *) die "未知参数 '$1'";;
  esac
done
printf '%s\n' "$content"
