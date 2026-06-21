# Changelog

All notable changes to this project are documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/), versioning [SemVer](https://semver.org/).

## [Unreleased]

### Added
- **`docs/INTEGRATIONS.md`**：把 cn-cc 当执行引擎被上层框架消费的**稳定契约**（fanout CLI / `--harness` 派活 / backends / allocate / cache / fleet / preflight / no-Gemini）；CivAgent 集成路线图（两仓干净依赖，非 flat merge）。
- **多 harness 适配（civagent 依赖整合的地基）**：`AGENTS.md` 跨 harness 入口（Claude Code / Codex / OpenCode 都读）；`fanout dispatch --harness ccb|codex|opencode` —— 派活执行器可选（ccb=Claude Code cc-* 分身 / codex=codex exec / opencode=opencode run），`<target>` 含义随 harness 变；`FANOUT_CODEX`/`FANOUT_OPENCODE` 可 stub。dispatch 自测 +3（codex/opencode/未知 harness）。
- 架构 SVG 图 `docs/architecture.svg`，嵌入 README（图在前 + 文本版收进 `<details>`）。
- GitHub repo About 描述 + 12 topics + homepage。

## [1.0.0] - 2026-06-21

First public release — the Chinese-model multi-agent coding workflow plus its full tooling and engineering layer.

### Added

**Foundation**
- `backends/` — Chinese-model backends: `cc_model_launch` shared core + 9 thin launchers + `cc-model-registry.tsv` + `cc-models` dispatcher + `cc-sync` (auto-follow Claude Code + model updates) + research-prompt + install/verify/prompts.
- `orchestration/fanout/SKILL.md` — 5-phase workflow + Phase 5 Review-Fix Loop v2 (deterministic gate first / keep-best / ≥2 confirmation passes / meta-reflect on non-convergence).
- `orchestration/ccb/ccb.config.example` — sanitized multi-window ccb topology template.
- `orchestration/cn-plugin/cn/` — `/cn:*` commands + `cn-dispatch` (derived from openai/codex-plugin-cc).
- `docs/WORKFLOW.md` — end-to-end pipeline + two run modes + maintenance layer + security boundary.

**`fanout` CLI tooling layer** — unified driver `orchestration/fanout/fanout` (doctor/fleet/preflight/task/template/dispatch/cache/allocate/workspace/experience/plan/goal/summary/ccb-sync/selftest):
- `fanout-doctor.sh` — environment recon + workflow recommendation.
- `fanout-preflight.sh` — go/no-go gate (deps / ccbd / ccb.config sanity / **no-Gemini guard** / `--probe` endpoint liveness / `--config-only`).
- `fanout-fleet.sh` + `fleet-launch.py` — bring up/check/stop the ccb fleet; strips `CLAUDE_CODE_*` (OAuth false-401) + detached tmux, with `--pty` (pty.fork) fallback. Solves "stuck-in-queue, no worker".
- `fanout-cache.sh` — result cache + **fan-in barrier** (dispatch N ⇒ return N) + timing + resume.
- `fanout-task.sh` — TASK scaffolder (new/log/done, cross GNU/BSD sed).
- `fanout-template.sh` + `templates/` — externalized prompt templates (impl/analysis/review).
- `fanout-dispatch.sh` — wraps `ccb ask` (render → dispatch → log; `--workspace`).
- `fanout-summary.sh` — round observability summary (status + elapsed).
- `fanout-allocate.sh` + `allocation.tsv` — bench-driven task-type → model allocation.
- `fanout-workspace.sh` + `workspaces/` — per-task **context isolation** (`System + Workspace + Tools + Memory + History`), inspired by Zleap-Agent.
- `fanout-experience.sh` — **experience memory** (completed work → reusable method → sanitized → recalled into workspace context), inspired by Zleap-Agent.
- `fanout-plan.sh` — multi-model planning panel (design panel).
- `fanout-goal.sh` — **goal mode**: declarative spec + deterministic acceptance gate.
- `fanout-ccb-sync.sh` + `launchd/com.user.fanout-ccb-sync.plist.example` — adapt after a ccb update (version drift / grafting check / ccbd restart).

**Agent Team** — `docs/AGENT_TEAM.md` (multi-model planning + hierarchical sub-agents: ccb fleet vs. native Claude Code subagents) + `orchestration/agent-team/team-review.workflow.mjs` (Workflow orchestration example).

**Frontend** — agy (Antigravity) as Frontend Implementer (manual or headless `agy --print`); frontend-only, never reviews (no-Gemini).

**Install** — `scripts/install-skill.sh` + `make install-skill` → install as a Claude Code Skill (`~/.claude/skills/fanout`, backs up existing); bilingual `/fanout` triggers.

**Engineering** — CI (`secret-scan` + `shell` + `node`), `scripts/scan-secrets.sh` + `scripts/check-shell.sh` (shared by Make/CI/pre-commit), `.gitleaks.toml`, `.shellcheckrc`, `.pre-commit-config.yaml`, `Makefile`, `.editorconfig`, `.gitattributes`, `package.json`, `SECURITY.md`, `CONTRIBUTING.md`, PR/issue templates. **14 test suites, 119 assertions; CI green.**

### Documentation
- Bilingual GitHub-standard README: English `README.md` + `README_ZH.md` (badges / TOC / architecture / CLI reference / workflow / security / acknowledgements). Acknowledges openai/codex-plugin-cc (Apache-2.0) + Zleap-Agent (concepts).

[Unreleased]: https://github.com/LeoLin990405/cn-cc-workflow/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/LeoLin990405/cn-cc-workflow/releases/tag/v1.0.0
