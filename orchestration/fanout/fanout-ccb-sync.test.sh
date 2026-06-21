#!/usr/bin/env bash
# fanout-ccb-sync.test.sh — 用 stub ccb 测版本漂移 + grafting + stamp (不碰真 ccb)
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
S="$HERE/fanout-ccb-sync.sh"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
pass=0; fail=0
ok(){ if eval "$2"; then echo "  ✓ $1"; pass=$((pass+1)); else echo "  ✗ $1"; fail=$((fail+1)); fi; }

# stub ccb: version → 假版本 + Install path; 其它(kill) → no-op
cat > "$TMP/ccb" <<EOF
#!/usr/bin/env bash
case "\$1" in
  version) echo "ccb (Claude Code Bridge) v9.9.9 abc 2026-01-01"; echo "Install path: $TMP/install";;
  *) exit 0;;
esac
EOF
chmod +x "$TMP/ccb"
export FANOUT_CCB="$TMP/ccb" FANOUT_STATE="$TMP/state" CCB_INSTALL="$TMP/install"
unset CCB_WORK CCB_CLAUDE 2>/dev/null || true

mkdir -p "$TMP/install/lib/provider_profiles"
touch "$TMP/install/lib/provider_profiles/api_shortcuts.py"

echo "fanout-ccb-sync tests"

out="$(bash "$S" check)"
ok "check 报版本漂移 (none → v9.9.9)" 'echo "$out" | grep -q "版本漂移"'
ok "check: grafting api_shortcuts.py 在" 'echo "$out" | grep -q "grafting api_shortcuts.py 在"'

bash "$S" adapt >/dev/null 2>&1
ok "dry-run 不写 stamp" '[ ! -f "$FANOUT_STATE/ccb-version" ]'

bash "$S" adapt --apply >/dev/null 2>&1
ok "apply 写 stamp=当前版本" 'grep -q "v9.9.9" "$FANOUT_STATE/ccb-version" 2>/dev/null'

out2="$(bash "$S" check)"
ok "apply 后 check 无漂移" 'echo "$out2" | grep -q "无漂移"'

rm "$TMP/install/lib/provider_profiles/api_shortcuts.py"
out3="$(bash "$S" check)"
ok "grafting 缺失被检出" 'echo "$out3" | grep -q "api_shortcuts.py 不见了"'

# adapt 带 CCB_WORK + 干净配置 → 跑 --config-only 校验 (stub ccb, 不碰真 ccbd)
touch "$TMP/install/lib/provider_profiles/api_shortcuts.py"   # 恢复 grafting
mkdir -p "$TMP/work/.ccb"
printf '[agents.cc-deepseek]\nmodel = "deepseek-v4-pro"\n' > "$TMP/work/.ccb/ccb.config"
out4="$(CCB_WORK="$TMP/work" bash "$S" adapt --apply 2>&1)"
ok "adapt 带 CCB_WORK 跑配置校验" 'echo "$out4" | grep -q "配置校验"'
ok "adapt 带 CCB_WORK 仍记录 stamp" 'grep -q "v9.9.9" "$FANOUT_STATE/ccb-version"'

bash "$S" nope >/dev/null 2>&1; ok "未知子命令 → 非0" '[ "$?" -ne 0 ]'

echo "fanout-ccb-sync: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
