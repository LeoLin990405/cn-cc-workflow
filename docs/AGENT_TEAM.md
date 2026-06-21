# Agent Team —— 多模型规划 + 层级 sub-agent

两个玩法：① 用多个模型**并行规划**，② 在 team 下再分 **sub-agent**。两者都能落地，关键是**选对底座**。

## 两个底座

| 底座 | 顶层跨模型 | 层级/sub-agent | 多模型来源 | 现实度 |
|---|---|---|---|---|
| **ccb fleet**（本仓 fan-out） | ✓ 每个 ccb agent = 独立 CC 实例 | 成员可开自己 sub-agent，但**同模型**；再经 ccb 嵌套**很脆** | ccb.config 里 9 家 | 顶层强，嵌套差 |
| **Claude Code 原生 subagent** | 靠 Bash-桥 custom agent | `Agent` 工具原生支持开 sub-agent + 层级 | `cn-dispatch`(国产) / `codex-rescue`(Codex) 等**已存在**的 custom agent | **层级/sub-agent 的对的底座** |

**关键**：本机已有 `cn-dispatch`（路由国产模型）和 `codex-rescue`（交 Codex）这两个 custom subagent 类型。所以 Claude Code 原生的 Agent 系统 + 这俩 = 天生的「多模型 + 可层级」team，比硬塞 ccb 嵌套干净。

## ① 多模型规划（planning panel）

把"拆解目标"同时发给多家，拿不同视角，再综合。两条路：

- **ccb 路**（本仓工具）：
  ```bash
  fanout plan "<goal>" --models cc-deepseek,cc-kimi,coder
  # 各模型把分解方案 Write 到 .fanout-cache/plans/<model>.plan.md, planner 综合成 Phase 1
  ```
- **原生路**（Claude Code Agent 工具）：planner 并行 spawn N 个 subagent，每个用 `agentType: cn-dispatch`（带不同 model 提示）或不同 custom agent，各产出一份分解，planner 综合。

综合 = planner（你/Claude）读 N 份方案，取交集+补盲点，定最终 plan。这是 **design panel** 模式（研究上比单一规划更全）。

## ② team 下分 sub-agent（层级）

**现实的 2 层结构**（够强，别追求任意层嵌套）：

```
顶层 team:   planner(Claude)
             ├─ 成员 A = cn-dispatch → 国产模型 (实现子任务)
             ├─ 成员 B = codex-rescue → Codex (审查/疑难)
             └─ 成员 C = Explore → 只读检索
   某成员任务复杂时（成员本身是完整 agent loop）:
             成员 A ── 再开自己的 sub-agent 做子分解
```

- 顶层用 `Agent` 工具 spawn 成员（`subagent_type` 选 cn-dispatch / codex-rescue / Explore / general-purpose）。
- 成员若是完整 agent，可在其内部再 spawn sub-agent（层级 +1）。
- 要**确定性编排**（fan-out/pipeline/loop）用 `Workflow` 工具：`agent(prompt, {agentType:'cn-dispatch'})` 把成员指到国产模型；`pipeline()` 串「实现→审查」。

## 诚实约束（别踩坑）

1. **原生 subagent 默认跑 Claude**；要多模型只能经 Bash-桥 custom agent（`cn-dispatch`/`codex-rescue`）。
2. **`Workflow` 嵌套只允许 1 层**（child workflow 内再 `workflow()` 会抛错）。要更深用 `Agent` 工具的 subagent-开-subagent。
3. **ccb 嵌套**（ccb agent 内再经 ccb 派活）未验证、脆，别用。
4. **守 no-Gemini**：team 任何成员/审查都不路由 Gemini（agy=Gemini，仅前端实现，不进 team review）。

## 选哪个

| 场景 | 用 |
|---|---|
| 真并行**实现**（多文件、各自 worktree、持久） | **ccb fleet**（本仓 fan-out + cache/barrier） |
| **层级 team / sub-agent / 确定性编排** | **Claude Code 原生**（Agent 工具 + cn-dispatch/codex + Workflow） |
| 多模型**规划** | 两者皆可（`fanout plan` 或 原生并行 subagent） |
| 跨模型**审查** | `coder`(Codex)；绝不 Gemini |

> 例子见 `orchestration/agent-team/team-review.workflow.mjs`（Workflow 脚本：plan panel → 跨模型实现 → Codex 审，确定性编排）。

## 已落地：Workspace 上下文隔离（借鉴 Zleap-Agent）

Zleap 的「别给小模型喂全部 context」已落到本仓：`orchestration/fanout/workspaces/*.workspace` 定义工位（main/code/sql/chinese/review/web），`fanout workspace context <name>` 按 **Context = System + Workspace + Tools + Memory + History** 组装该工位**只该看的**分层上下文：

```bash
fanout workspace list                       # 列工位
fanout workspace context code --task "..."   # 看 code 工位的分层 context
fanout dispatch cc-minimax --workspace code --template impl --set ...  # 派活时前缀注入
```

每个工位绑定：专属 prompt + 启用的 tools + memory 范围 + bench 推荐模型（`models: @bench:code` 自动走 allocation）。这把 `allocation.tsv`（只映射模型）升级成完整 **context profile**——弱模型每个子任务不被全量工具/记忆/规则淹没。Zleap 无 license + 异构栈，**只借思想，代码独立实现**。

### Experience memory（Zleap 三分记忆里的"经验"）

任务完成 → 抽可复用方法 → 脱敏 → 按工位存 → 未来同类任务**自动回灌**到 workspace context 的 Memory 段：
```bash
echo "用 defensive copy 避免改输入区间" | fanout experience add code "防御拷贝技巧"   # 脱敏闸门(明文 key 拒入)
fanout experience recall code              # 取该工位经验
fanout workspace context code              # Memory 段已自动注入上面的经验
```
库在 `${FANOUT_STATE:-~/.config/fanout}/experience/<ws>/`（不入仓，runtime 累积）。这和 Leo「蒸馏 skill」的习惯同构——完成的活沉淀成可复用方法。
