# gh-review

Review the pull request like a code reviewer.

Lead with findings ordered by severity. Focus on bugs, regressions, security problems, behavior changes, and missing tests. Use file and line references when available. Keep summary secondary to findings.

For dotfiles or agent-config repositories, explicitly inspect `.gitignore` and `docs/secrets.md` when reviewing secret handling, live config files, MCP config, installer overwrite behavior, or local machine assumptions.
