#!/usr/bin/env bash
# fanout-doctor.sh — 环境侦察 + 工作流顾问
#
# 在任意机器上探测: 装了哪些 Agent/CLI、配了哪些 provider API(只看 var 名不读值),
# 据此推荐怎么搭这条 fan-out 工作流。不打印任何密钥值。
#
#   用法: scripts/fanout-doctor.sh         # 人类可读报告
#         scripts/fanout-doctor.sh --quiet # 只出结论行
set -uo pipefail

QUIET=0; [ "${1:-}" = "--quiet" ] && QUIET=1
say()  { [ "$QUIET" -eq 1 ] || printf '%s\n' "$*"; }
g="✓"; x="—"

# ── key 是否配置 (live env 或常见 rc 文件里出现该 var 名; 绝不读值) ──
RCFILES=(
  "$HOME/.config/cc-model-secrets.env" "$HOME/.zshrc" "$HOME/.zprofile"
  "$HOME/.bashrc" "$HOME/.bash_profile" "$HOME/.profile"
)
key_configured() { # 任一参数(候选 var 名)被配置即算 yes
  local v
  for v in "$@"; do
    [ -n "$(eval "printf '%s' \"\${$v:-}\"")" ] && return 0
    local f
    for f in "${RCFILES[@]}"; do
      [ -f "$f" ] && grep -qE "^[[:space:]]*(export[[:space:]]+)?$v=" "$f" && return 0
    done
  done
  return 1
}
has() { command -v "$1" >/dev/null 2>&1; }

# ── provider 规格: launcher | key_env(可多个候选) | 最佳任务 ──
# 行格式: provider<TAB>launcher<TAB>key1[,key2]<TAB>best-task
PROVIDERS="$(cat <<'EOF'
deepseek	cc-deepseek	DEEPSEEK_API_KEY	推理 / 复杂算法
glm	cc-glm	GLM_API_KEY,ZAI_API_KEY	中文文档 / 推理
kimi	cc-kimi	KIMI_API_KEY	长上下文 (>50K)
qwen	cc-qwen	DASHSCOPE_API_KEY	SQL / 阿里生态
doubao	cc-doubao	ARK_API_KEY	通用编码 / 火山生态
minimax	cc-minimax	MINIMAX_API_KEY	数学 / 通用 frontier
mimo	cc-mimo	MIMO_API_KEY	通用 / 兜底
stepfun	cc-stepfun	STEPFUN_API_KEY	数学 / 逻辑 (thinking)
longcat	cc-longcat	LONGCAT_API_KEY	通用
EOF
)"

say "╔══════════════════════════════════════════════╗"
say "║  fan-out 工作流 — 环境侦察 + 顾问             ║"
say "╚══════════════════════════════════════════════╝"

# ── 1) 核心角色 CLI ──
say ""; say "── 核心角色 CLI ──"
declare -A ROLE
for spec in "claude:Planner/Executor (Claude Code)" "codex:Reviewer (独立 frontier)" \
            "ccb:Dispatch 桥 (多窗口扇出)" "agy:Frontend (Antigravity)" \
            "opencode:备选实现/审查" "node:dep" "git:dep" "tmux:dep (ccb panes)"; do
  c="${spec%%:*}"; desc="${spec#*:}"
  if has "$c"; then ROLE[$c]=1; say "  $g $(printf '%-9s' "$c") $desc"
  else ROLE[$c]=0; say "  $x $(printf '%-9s' "$c") $desc"; fi
done

# ── 2) 实现层后端 (cc-* launcher + API key) ──
say ""; say "── 实现层后端 (launcher + API key) ──"
impl_ready=0; impl_nokey=0; impl_noinst=0
READY_LIST=""
while IFS=$'\t' read -r prov launcher keys task; do
  [ -n "$prov" ] || continue
  inst=$x; keyst=$x; state=""
  has "$launcher" && inst=$g
  IFS=',' read -ra kcands <<< "$keys"
  if key_configured "${kcands[@]}"; then keyst=$g; fi
  if [ "$inst" = "$g" ] && [ "$keyst" = "$g" ]; then
    state="就绪"; impl_ready=$((impl_ready+1)); READY_LIST="$READY_LIST $launcher"
  elif [ "$inst" = "$g" ]; then
    state="缺 key(${keys//,/ 或 })"; impl_nokey=$((impl_nokey+1))
  elif [ "$keyst" = "$g" ]; then
    state="缺 launcher(install.sh)"; impl_noinst=$((impl_noinst+1))
  else state="未配置"; fi
  say "  launcher:$inst key:$keyst  $(printf '%-12s' "$launcher")  $(printf '%-16s' "$task")  $state"
done <<< "$PROVIDERS"

# ── 3) API 配置小结 ──
say ""; say "── 小结 ──"
ncli=0; for c in claude codex ccb agy opencode; do [ "${ROLE[$c]:-0}" = 1 ] && ncli=$((ncli+1)); done
say "  Agent/CLI 就绪: $ncli (planner/reviewer/dispatch/frontend/alt 里)"
say "  实现后端就绪: $impl_ready / 9   (缺 key $impl_nokey · 缺 launcher $impl_noinst)"

# ── 4) 推荐工作流 ──
say ""; say "── 推荐工作流 ──"
recs=""
add() { recs="$recs\n  • $1"; }

if [ "${ROLE[ccb]:-0}" = 1 ] && [ "$impl_ready" -ge 2 ] && [ "${ROLE[codex]:-0}" = 1 ]; then
  add "✅ 完整 fan-out: ccb 多窗口扇出 → $impl_ready 个后端并行实现(各自 worktree) → Codex 审 → Phase 5 有界 loop。结果走 fanout-cache 缓存 + fan-in barrier(发 N 收 N)。"
elif [ "$impl_ready" -ge 1 ] && [ "${ROLE[ccb]:-0}" = 0 ]; then
  add "⚙️ 单机轻量: 没 ccb → 用 /cn:* 插件 顺序派活(无自动 review loop)。装 ccb 可解锁完整扇出。"
elif [ "$impl_ready" -ge 1 ]; then
  add "⚙️ 半套: $impl_ready 个后端可用，按需手动扇出。"
else
  add "❌ 还没有就绪的实现后端：先 ./backends/install.sh 装 launcher，并在 ~/.config/cc-model-secrets.env 配 API key。"
fi

if [ "${ROLE[codex]:-0}" = 0 ]; then
  add "⚠️ 无 Codex(reviewer)：review 路径降级。生成≠审查仍要跨家——用一个强国产后端(deepseek/minimax)当 reviewer，**别用 Gemini**。"
fi
if [ "${ROLE[agy]:-0}" = 1 ]; then
  add "🎨 agy 可用：前端/UI 子任务给 Antigravity(手动 或 agy --print)。仅前端，不进 review loop / 不当 reviewer(后端=Gemini)。"
else
  add "🎨 无 agy：前端走手动 IDE 或某个后端兜底。"
fi
if [ "${ROLE[claude]:-0}" = 0 ]; then
  add "⚠️ 无 claude(Claude Code)：本工作流的 executor/整合层缺失，先装 @anthropic-ai/claude-code。"
fi
say "$(printf "$recs")"

# ── 5) 最佳任务分配 (就绪后端) ──
if [ -n "$READY_LIST" ]; then
  say ""; say "── 就绪后端的建议任务分配 ──"
  while IFS=$'\t' read -r prov launcher keys task; do
    [ -n "$prov" ] || continue
    case " $READY_LIST " in *" $launcher "*) say "  $(printf '%-12s' "$launcher") → $task";; esac
  done <<< "$PROVIDERS"
  say "  (实测最优分配见 skill 记忆 model-task-allocation 基准)"
fi

if [ "$QUIET" -eq 1 ]; then
  echo "agents=$ncli backends_ready=$impl_ready/9 ccb=${ROLE[ccb]:-0} codex=${ROLE[codex]:-0} agy=${ROLE[agy]:-0}"
fi
