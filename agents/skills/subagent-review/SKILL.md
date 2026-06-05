---
name: subagent-review
description: Use when implementation work needs independent review delegation or Claude Code subagents before handoff.
---

# Subagent Review

Use subagents only when the task has separable review or research surfaces. Keep each request narrow and pass raw artifacts rather than conclusions.

## Workflow

1. Define the review target and expected output.
2. Dispatch only if a subagent tool is available and allowed.
3. Ask one pass for spec compliance and another pass for code quality when the change is substantial.
4. Review findings in the main thread before acting on them.
5. Verify the integrated result after applying any accepted feedback.

## Common Mistakes

- Treating subagent output as automatically correct.
- Passing your intended answer instead of the artifact.
- Spawning agents for tasks that need shared state or immediate user judgment.
