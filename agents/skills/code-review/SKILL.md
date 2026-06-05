---
name: code-review
description: Use when reviewing code changes for bugs, regressions, security issues, and missing tests.
---

# Code Review

Lead with findings, ordered by severity.

For each finding include:

- file and line when available;
- the concrete risk;
- why the current behavior is wrong or fragile;
- a focused fix direction.

If no issues are found, say so and mention remaining test gaps or residual risk.

For dotfiles or agent-config repositories, check `.gitignore` and `docs/secrets.md` before concluding that secrets or live local config are handled safely.
