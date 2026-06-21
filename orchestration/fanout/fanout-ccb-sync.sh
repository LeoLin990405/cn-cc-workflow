#!/usr/bin/env bash
# fanout-ccb-sync.sh — ccb 更新后同步适配 (类比 backends/bin/cc-sync 之于 claude-code)
#
# ccb 升级后要做的适配 (把已知坑变成自动检查):
#   1. grafting 依赖 (api_shortcuts.py) 还在吗 —— claude+url 嫁接全靠它
#   2. ccbd 需重启 —— `ccb update` 不会重启在跑的守护, 旧代码会继续跑 (已知坑)
#   3. 重新 preflight (ccb.config 在新版本下仍健全 + no-Gemini)
#   4. 记录新版本, 供下次比对
#
#   check            打印 当前/上次 ccb 版本 + 是否漂移 + grafting 健全
#   adapt [--apply]  漂移则适配: 校验 grafting → (--apply 才真 kill ccbd) → preflight → 记录版本
#                    不带 --apply = dry-run (只报告, 不动 ccbd / 不写 stamp)
#   env: FANOUT_CCB(默认 ccb) / CCB_WORK / CCB_CLAUDE / FANOUT_STATE(默认 ~/.config/fanout) / CCB_INSTALL(覆盖 install path)
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CCB="${FANOUT_CCB:-ccb}"
STATE="${FANOUT_STATE:-$HOME/.config/fanout}"
STAMP="$STATE/ccb-version"
die(){ echo "fanout-ccb-sync: $*" >&2; exit 2; }

ccb_ver(){ "$CCB" version 2>/dev/null | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' | head -1; }
ccb_install(){
  if [ -n "${CCB_INSTALL:-}" ]; then printf '%s' "$CCB_INSTALL"; return; fi
  local p; p="$("$CCB" version 2>/dev/null | sed -n 's/.*Install path:[[:space:]]*//p' | head -1)"
  [ -n "$p" ] && printf '%s' "$p" || printf '%s' "$HOME/.local/share/codex-dual"
}
grafting_ok(){ local ins; ins="$(ccb_install)"; [ -n "$ins" ] && [ -f "$ins/lib/provider_profiles/api_shortcuts.py" ]; }

cmd_check(){
  local cur last; cur="$(ccb_ver)"; last="$(cat "$STAMP" 2>/dev/null || echo '(none)')"
  echo "ccb 当前: ${cur:-未知}   上次记录: $last"
  [ -n "$cur" ] || { echo "  ⚠ 取不到 ccb 版本 (ccb 没装?)"; return 0; }
  if [ "$cur" != "$last" ]; then echo "  → 版本漂移 ($last → $cur): 跑 'fanout ccb-sync adapt --apply' 适配"
  else echo "  ✓ 无漂移"; fi
  if grafting_ok; then echo "  ✓ grafting api_shortcuts.py 在 ($(ccb_install))"
  else echo "  ✗ grafting api_shortcuts.py 不见了 — claude+url 嫁接可能失效, 需人工查 ccb 新版"; fi
}

cmd_adapt(){
  local apply=0; [ "${1:-}" = "--apply" ] && apply=1
  local cur last; cur="$(ccb_ver)"; last="$(cat "$STAMP" 2>/dev/null || echo '')"
  [ -n "$cur" ] || die "取不到 ccb 版本"
  if [ "$apply" -eq 1 ]; then echo "── ccb 适配 (${last:-none} → $cur) ──"; else echo "── ccb 适配 (${last:-none} → $cur) [dry-run] ──"; fi

  # 1) grafting 依赖
  if grafting_ok; then echo "  ✓ grafting api_shortcuts.py 在"
  else echo "  ✗ grafting 依赖丢失 — 新版 ccb 可能改了 provider_profiles, 嫁接方案需人工适配"; fi

  # 2) ccbd 重启 (ccb update 不重启在跑的守护 → 旧代码)
  local proj
  for proj in "${CCB_WORK:-}" "${CCB_CLAUDE:-}"; do
    [ -n "$proj" ] || continue
    if [ "$apply" -eq 1 ]; then
      (cd "$proj" 2>/dev/null && "$CCB" kill >/dev/null 2>&1) && \
        echo "  ✓ kill ccbd @ $proj — 下次 'cd $proj && ccb' 起守护即加载新代码 (claude-only 用 env CLAUDE_START_CMD=claude)"
    else
      echo "  [dry] 需重启 ccbd @ $proj (ccb update 不自动重启, 旧代码继续跑)"
    fi
  done
  [ -z "${CCB_WORK:-}${CCB_CLAUDE:-}" ] && echo "  ⚠ 未设 CCB_WORK/CCB_CLAUDE — 跳过 ccbd 重启 (设后重跑)"

  # 3) 配置校验 (--config-only: 不依赖 ccbd 存活, 因为上面可能刚 kill 掉它)
  if [ "$apply" -eq 1 ] && [ -n "${CCB_WORK:-}" ] && [ -f "$CCB_WORK/.ccb/ccb.config" ]; then
    echo "  配置校验 (no-Gemini + 健全):"
    bash "$HERE/fanout-preflight.sh" --config-only "$CCB_WORK/.ccb/ccb.config" 2>&1 | sed 's/^/    /' || true
  fi

  # 4) 记录版本
  if [ "$apply" -eq 1 ]; then mkdir -p "$STATE"; printf '%s\n' "$cur" > "$STAMP"; echo "  ✓ 记录 $cur → $STAMP"
  else echo "  [dry] 未写 stamp; 加 --apply 落实"; fi
}

sub="${1:-}"; shift || true
case "$sub" in
  check) cmd_check "$@";;
  adapt) cmd_adapt "$@";;
  ''|-h|--help) sed -n '2,14p' "$0";;
  *) die "未知子命令 '$sub' (check|adapt)";;
esac
