---
description: Intelligently route a task to the best Chinese model backend
argument-hint: '<task description>'
context: fork
allowed-tools: Bash(node:*)
---

Route this request to the `cn:cn-dispatch` subagent.
The final user-visible response must be the model's output verbatim.

Raw user request:
$ARGUMENTS

Rules:
- The subagent selects the model using its cn-routing skill.
- Return the output verbatim. Do not paraphrase or add commentary.
- If the user did not supply a request, ask what they need.
