---
name: cn-result-handling
description: Rules for presenting Chinese model backend output back to the user
user-invocable: false
---

# CN Result Handling

When the companion script returns output from a Chinese model backend:

- Return the model's stdout **verbatim**. Do not paraphrase or summarize.
- If the model produced code, preserve it exactly including comments and formatting.
- If the output is in Chinese, keep it in Chinese. Do not translate unless asked.
- Prefix the output with a brief one-line tag: `[cn:model-name]` so the user knows which backend responded.
- If the model returned an error or empty output, report it clearly and stop. Do not attempt to solve the task yourself as a fallback.
- If the companion script reports the model is unavailable, direct the user to `/cn:setup`.
