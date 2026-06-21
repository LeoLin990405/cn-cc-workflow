// team-review.workflow.mjs — Agent Team 确定性编排示例 (给 Claude Code 的 Workflow 工具跑)
//   ① 规划面板: 多模型并行出分解方案 → 综合
//   ② 实现→审查: pipeline (每个子任务 跨模型实现 → Codex 审, 无 barrier)
// agentType 走已存在的 Bash-桥 custom agent: cn-dispatch(国产) / codex-rescue(Codex)。
// 守 no-Gemini: 审查只用 codex。
// 注意: 本文件由 Claude Code 的 Workflow 工具执行 (含顶层 return / agent()等注入全局),
//       不是独立 node 模块 —— 别 `node` 直接跑, 也别 node --check (顶层 return 会报错)。
export const meta = {
  name: 'cn-team-review',
  description: '多模型规划 → 跨模型实现 → Codex 审查 (Agent Team 确定性编排)',
  phases: [
    { title: 'Plan' },
    { title: 'Implement' },
    { title: 'Review' },
  ],
}

const goal = (args && args.goal) || '示例目标：给 X 模块加单测并全绿'

// ① 规划面板 —— 3 家并行拆解, 取不同视角
phase('Plan')
const PLANNERS = ['cn-dispatch', 'cn-dispatch', 'codex-rescue']
const plans = (await parallel(PLANNERS.map((p, i) => () =>
  agent(`你是规划者#${i + 1}。把目标拆成 3-6 个可并行子任务, 每个标 scope + 建议实现模型 + 改的文件。\n目标: ${goal}`,
    { label: `plan:${p}:${i}`, phase: 'Plan', agentType: p })))).filter(Boolean)

const synthesis = await agent(
  `综合下面多份规划方案: 去重 + 补盲点, 产出最终子任务清单(每条带 建议模型 + 文件):\n\n${plans.join('\n---\n')}`,
  { label: 'plan:synthesize', phase: 'Plan' })

// ② 实现 → 审查 —— pipeline: 每个子任务 跨模型实现, 完即 Codex 审 (生成≠审查)
const SUBTASKS = [
  { id: 't1', agent: 'cn-dispatch', scope: '核心实现' },
  { id: 't2', agent: 'cn-dispatch', scope: '边界 / 算法' },
]
const results = await pipeline(
  SUBTASKS,
  (t) => agent(`实现子任务「${t.scope}」。必须用 Read/Edit/Write 真改文件, 不要只在 chat 输出。`,
    { label: `impl:${t.id}`, phase: 'Implement', agentType: t.agent }),
  (impl, t) => agent(`审查这个改动是否 正确/安全/无回归。输出 VERDICT: ACCEPTED 或 NEEDS FIX + 问题列表:\n${impl}`,
    { label: `review:${t.id}`, phase: 'Review', agentType: 'codex-rescue' })
    .then((verdict) => ({ id: t.id, impl, verdict })))

return { goal, synthesis, results: results.filter(Boolean) }
