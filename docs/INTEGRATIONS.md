# Using open-sakanafugu as an execution engine

open-sakanafugu is built to be **consumed by higher-level frameworks** as their multi-agent *execution layer*, while the framework on top owns the *orchestration patterns* and UX. The first such consumer is [**CivAgent**](https://github.com/LeoLin990405/civagent) — a research framework that encodes multi-agent orchestration as 57 historical governance regimes; civagent stays the foundation/umbrella, open-sakanafugu is the engine it calls.

This doc is the **stable contract** downstream depends on.

## What downstream gets

| Capability | Interface | Notes |
|---|---|---|
| Backends (Chinese-model fleet) | `cc-*` launchers (`cc-deepseek` `cc-glm` …) on `$PATH` | installed via `./backends/install.sh`; keys in `~/.config/cc-model-secrets.env` |
| Harness-agnostic dispatch | `fanout dispatch <target> --harness ccb\|codex\|opencode` | one call dispatches an implementer on any harness |
| Bench-driven model choice | `fanout allocate <task-type> [--top]` | task-type → recommended model |
| Result cache + fan-in barrier | `fanout cache …` | dispatch N ⇒ return N before next round |
| Fleet lifecycle | `fanout fleet status\|up\|down` | strips `CLAUDE_CODE_*` + detached tmux / pty.fork |
| Preflight gate | `fanout preflight` | deps · ccbd · ccb.config sanity · **no-Gemini guard** |

All of the above are plain bash on `$PATH` (install the skill or add `orchestration/fanout/` to `$PATH`) — language-agnostic, callable from a Node/Go/Python framework via `child_process`/`exec`.

## Shared policy

- **No Gemini** in the review path (both projects enforce this — civagent's `engine/models/providers.json` `_policy` matches open-sakanafugu's no-Gemini guard).
- **Keys never in either repo** — only `~/.config/cc-model-secrets.env`.

## How CivAgent consumes it

CivAgent's `engine/v5/backends.mjs` already maps its backend ids to open-sakanafugu's launchers (`cn:doubao → cc-doubao`, …) — so it is **already an implicit consumer**. The integration roadmap makes that dependency explicit:

1. **Now (foundation)** — open-sakanafugu is a stable, harness-agnostic engine (`fanout` CLI + `AGENTS.md` + `--harness`). ✅
2. **Next** — civagent declares open-sakanafugu as a dependency (README/CREDITS + a presence check that the `cn:*` backends resolve to installed `cc-*` launchers).
3. **Future** — civagent routes implementer dispatch through `fanout dispatch --harness` to inherit the cache + fan-in barrier + review-fix loop, instead of spawning `cc-*` directly. Best landed **after** civagent's in-flight `refactor/backend-arg-contract` merges (it touches the same `backends.mjs`).

> Two repos, clean dependency (civagent → open-sakanafugu). Not a flat merge: licenses differ (open-sakanafugu Apache-2.0, civagent MIT) and civagent carries a large frontend — a documented dependency keeps both clean and reversible.
