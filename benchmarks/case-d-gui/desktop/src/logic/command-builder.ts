export const buildPlanCmd = (goal: string): string => `fuguectl plan "${goal}"`;

export const buildDispatchCmd = (taskId: string, agent: string, harness: string): string =>
  `fuguectl dispatch ${agent} --harness ${harness} --task ${taskId}`;

export const buildIntegrateCmd = (taskId: string): string => `fuguectl integrate --task ${taskId}`;

export const buildReviewCmd = (taskId: string): string =>
  `fuguectl dispatch coder --harness codex --task ${taskId}`;

export const buildLoopCmd = (taskId: string): string => `fuguectl loop status --task ${taskId}`;
