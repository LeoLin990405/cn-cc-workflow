#!/usr/bin/env bash
# fanout-goal.sh — 目标模式: 声明式 goal spec + 确定性验收门
#
# 把 loop v2 + bench 分配 + cache 用一个声明式目标包起来。spec 是 key: value 行:
#   outcome:  一句话目标
#   gate:     一条能跑的客观验收命令 (如 pytest -q && npm run build)
#   rubric:   Codex 主观审的重点
#   rounds:   loop 封顶轮数
#   allocate: auto | 手动
#
#   template          打印 spec 模板
#   show  <spec>      解析并显示 spec 字段
#   check <spec>      跑 gate 命令: 达成 exit 0, 否则 1 (Phase 5 loop 的客观验收门)
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
die(){ echo "fanout-goal: $*" >&2; exit 2; }
field(){ sed -n "s/^$1:[[:space:]]*//p" "$2" | head -1; }

cmd_template(){
  cat <<'EOF'
# fanout goal spec — `fanout goal check <thisfile>` 跑 gate 判目标是否达成
outcome: <一句话目标>
gate: <一条能跑的验收命令, 如 pytest -q && npm run build>
rubric: correctness / security / 无回归
rounds: 3
allocate: auto
EOF
}

cmd_show(){
  local f="${1:-}"; [ -n "$f" ] && [ -f "$f" ] || die "无 spec 文件: ${f:-(空)}"
  printf 'outcome:  %s\n' "$(field outcome "$f")"
  printf 'gate:     %s\n' "$(field gate "$f")"
  printf 'rubric:   %s\n' "$(field rubric "$f")"
  printf 'rounds:   %s\n' "$(field rounds "$f")"
  printf 'allocate: %s\n' "$(field allocate "$f")"
}

cmd_check(){
  local f="${1:-}"; [ -n "$f" ] && [ -f "$f" ] || die "无 spec 文件: ${f:-(空)}"
  local gate; gate="$(field gate "$f")"
  [ -n "$gate" ] || die "spec 无 gate 行"
  echo "── goal gate: $gate ──"
  if bash -c "$gate"; then echo "✓ 目标达成 (gate 通过)"; exit 0
  else echo "✗ 目标未达成 (gate 失败) → 进 Phase 5 loop 修"; exit 1; fi
}

sub="${1:-}"; shift || true
case "$sub" in
  template) cmd_template;;
  show)     cmd_show  "$@";;
  check)    cmd_check "$@";;
  ''|-h|--help) sed -n '2,18p' "$0";;
  *) die "未知子命令 '$sub' (template|show|check)";;
esac
