# 端到端工作流详解

把一个需求从「一句话」走到「过审合进主 branch」的完整流水线。
四个角色，七个阶段，全程可复述、可中断、可审计。

---

## 角色

| 层 | 谁 | 干什么 | 不干什么 |
|---|---|---|---|
| 战略 Planner | **Claude Desktop**（Opus, 1M） | 写需求、拆任务、定验收标准 | 不进 ccb pane、不写实现代码 |
| 执行+监工 | **Claude Code**（fanout skill） | 调度分身、整合、质量门、跑测试、记 TASK | 不亲自硬写大段实现（除 Phase 5 patch） |
| 实现 Implementers | **9 国产 CC 分身**（ccb work/ark 窗口） | 各自 worktree 里写子任务 | 不互相看代码、不碰主 branch |
| 前端 Frontend（opt-in） | **Antigravity（`agy` CLI）** | 前端/UI 子任务，手动 IDE 或 headless `agy --print` | **不进 Phase 5 loop、不当 reviewer**（后端=Gemini，守 no-Gemini） |
| 审查 Reviewer | **Codex**（gpt-5.5, ccb review 窗口） | 对抗式审查、给 VERDICT+Findings | 不写实现（保持生成≠审查独立性）；review 路径绝不用 Gemini |

> 维护层 **cc-sync** 不在请求路径上，是后台 launchd 守护：CC 升级跟随 + 模型刷新 + 月度重建。

---

## 七阶段流水线

### Phase 0 — 立任务（Planner）
Claude Desktop 把需求写成任务文件 `~/.claude/tasks/TASK-YYYY-MM-DD-NNN.md`：需求 / 子任务（标注指派哪个 AI）/ 验收标准 / 输出文件。这是整条流水线的 single source of intent。

### Phase 1 — 拆分指派（fanout）
Claude Code 读任务，拆成可并行的子任务，按决策树选后端：
- 中文场景 / 国内 API / SQL → 国产分身（doubao/qwen/glm/kimi…）
- 英文 / 算法 / 重构 → coder(Codex) 或强推理分身（deepseek/minimax）
- 数学逻辑 → stepfun
- 一份子任务 = 一份独立可复制 prompt（**禁止一份通用 prompt 群发**）。

### Phase 2 — 并行实现 + 缓存 + fan-in barrier（Implementers）
`cd proj && ccb` 起窗口后：
1. **开本轮缓存**：`fanout-cache.sh init <round> t1:cc-deepseek t2:cc-glm t3:agy ...` —— 声明本轮发出的 N 个任务（fan-out manifest）。
2. **派活**：`ccb ask <agent> --compact "<prompt>"` 异步，每个分身在自己 worktree 里改。
3. **结果先进缓存**：每个 agent 产物 `fanout-cache.sh put <round> <task_id> <file>`（死/超时 → `fail`，也算"已返回"）。**绝不从易失的 chat/scrollback 读**。
4. **fan-in barrier（硬闸）**：`fanout-cache.sh barrier <round> --wait 600` —— **发出 N 个就必须收回 N 个**（全部 terminal）才 exit 0，否则不许进 Phase 3。卡住的任务在此暴露，绝不静默丢。

> 逻辑契约：Claude Desktop 发出多少任务，就要收回多少任务，才进入下一轮。每轮（含 Phase 5 每一圈）都过这道 barrier。

### Phase 3 — 整合（fanout）
barrier 过了（N 全回）后，Claude Code 从缓存取产物（`fanout-cache.sh collect <round>`）+ cherry-pick 各分身 worktree 改动到主 branch 工作分支，
解冲突、统一风格，跑本地 sanity（build/test/lint）打底。

### Phase 4 — 审查（Reviewer）
`ccb ask coder --compact "审查这段改动：<diff>"` → Codex 给出 `VERDICT`（ACCEPTED / NEEDS FIX）+ `Findings`。
生成≠审查：实现是国产分身，审查是 Codex，跨家独立。

### Phase 5 — Review-Fix Loop（有界闭环，2026-06 据 loop 工程研究升级）
自动迭代 **fix → re-review** 直到过审，封顶兜底。详见 `orchestration/fanout/SKILL.md` Phase 5，要点：

1. **确定性门优先** — 每轮先 build/test/lint（客观 pass/fail），红的必修，不浪费 Codex。
2. **Codex 主观审（增量）** — 第 2 轮起只审本轮 diff（省 token + 聚焦）。
3. **keep-best 防退化** — 某轮比上轮还差/引入新问题 → `git reset` 回最优版，丢坏改动（防 degeneration of thought）。
4. **≥2 次确认审** — 连第一次 ACCEPTED 也补一次独立确认（验证是概率性的）。
5. **Fix = Claude Edit patch**（v4 硬规矩，不回分身重写）+ 每轮写进 TASK 文件留审计。
6. **退出三态**：ACCEPTED→DONE / 超 MAX_ROUNDS(3)→升级人工 / **不收敛→Meta-Reflector**（先反思「为什么修不动」给诊断+建议，再升级，不是简单重试）。

研究依据：1-2 轮拿 ~75% 改进、硬封顶 5-6 轮防震荡、生成≠审查 +~20%。
sources: [LLM Verification Loops](https://timjwilliams.medium.com/llm-verification-loops-best-practices-and-patterns-07541c854fd8) · [Loop Engineering 2026](https://shaam.blog/articles/loop-engineering-ai-agents) · Reflexion / Self-Refine。

### Phase 6 — 收尾（fanout）
过审 → 合进主 branch，TASK 文件标 `DONE`，清理 worktree，写记忆（非显然的踩坑/决策）。

---

## 两种跑法

| | 单机轻量（`/cn:*` 插件） | 完整多 Agent（ccb 多窗口） |
|---|---|---|
| 何时用 | 一两个子任务、快验证 | 真扇出、要审查闭环 |
| 启动 | Claude Code 里 `/cn:team` `/cn:ask` | `cd proj && ccb` 起 planner/work/ark/review |
| 隔离 | 同进程，无 worktree | 每分身独立 worktree |
| 审查 | 手动 | Phase 4-5 自动闭环 |
| 配置 | 无需 ccb.config | 需 `.ccb/ccb.config`（拷 `.example` 填 key） |

---

## 维护层：cc-sync（后台 launchd）

```bash
cc-sync cli              # 全 envs + 主 claude 升到最新 @anthropic-ai/claude-code
cc-sync models [--apply] # 探各 provider /v1/models, 报告/追加新模型 (默认档不动)
cc-sync research         # agent: 读各家官方文档 → 学习 → 重建 launcher → 活体验证
cc-sync all              # cli + models
```

- `WatchPaths` 钉住全局 claude-code 的 `package.json` → 上游一升级就跟随。
- 月度 `cc-sync research`（launchd `StartCalendarInterval` 每月 1 号 05:00）→ 文档驱动重建。
- **默认/旗舰档变更永远手动** —— 模型适配度需要人判断，自动只「提议」不「换默认」。

---

## 安全边界

- key 只存 `~/.config/cc-model-secrets.env`（被 launcher 读，最高优先级）；仓里只有 `ccb.config.example`。
- `.gitignore` 忽略 `**/.ccb/ccb.config` / `*secrets*.env` / `.env*`；push 前硬扫密钥，0 命中才推。
- 个人路径已泛化为 `$CCB_WORK` / `$CCB_CLAUDE` / `$TASKS` 等占位 + `~/...` 约定，按你的环境替换；提交前硬扫密钥，0 命中才推。
- 审查/第二意见走 **Codex 或 opencode**，**不用 Gemini**（硬规矩）。
