---
name: cn-team
description: How to parallelize a task across multiple provider-backed model profiles and synthesize their outputs for unified review
user-invocable: false
---

# Provider Team Fan-Out

Use this skill when `/cn:team` (or the companion `team` subcommand) broadcasts one task
to several model profiles as the supplementary pool in a review/frontend/backend triangle.

## When to split work

- You want several independent model-backed opinions on the same problem, then a unified review.
- You are assigning overflow or supplementary work and want to compare candidates before
  integrating one.
- Prefer a single `/cn:<model>` or `/cn:ask` when one backend is clearly the right tool —
  parallel dispatch costs one run per member and burns more quota.

## Choosing members

- The default pool `qwen, glm, kimi` is complementary by design: coding,
  Chinese-language reasoning, long-context.
- Override with `--models qwen:token,glm:max,kimi` to pin a per-member profile via
  `model:profile`. A bare member name uses the wrapper default.
- `--all` runs every registered profile; reserve it for broad cross-checks.
- Match members to the task using the `cn-routing` decision matrix rather than always
  defaulting.

## Presenting results (unified review)

- Keep each profile's section verbatim and tagged `[cn:<model>]`; preserve code and
  Chinese exactly.
- After the sections, add a short synthesis: agreements, disagreements, and your
  recommended pick with reasons.
- Never silently merge the outputs into one blended answer that hides which backend said
  what.
- Report skipped or unavailable profiles and point to `/cn:setup`; never substitute your
  own answer for a profile that failed.

## Triangle context

- In the larger triangle, Claude orchestrates and reviews, Codex owns the backend, and
  the Antigravity CLI (`agy`) owns the frontend.
- `/cn:team` is the elastic model pool that feeds supplementary work back to Claude for the
  unified review gate.
- See `docs/triangle-workflow.md` for the full topology and where this pool plugs in.
