# Claude Plugins

This repository tracks plugin choices and usage notes only. It does not vendor plugin code and installers do not run plugin install commands.

## Recommended

- `claude-code-setup`: official Claude Code setup plugin. Use it after cloning a real project to analyze the codebase and suggest MCPs, skills, hooks, subagents, and slash commands.
- `superpowers`: disciplined workflow plugin for planning, TDD, debugging, verification, code review, and worktrees.

## Optional External Tools

- `graphify`: optional CLI and assistant skill for turning a project into a queryable knowledge graph. Keep it opt-in; install with `uv tool install graphifyy` and then run `graphify install --project` only in repositories where graph-backed analysis is wanted.

## Manual Install

Review the current Claude plugin marketplace before installing because package names can change.

```text
/plugin install claude-code-setup@claude-plugins-official
/plugin install superpowers@claude-plugins-official
```

Then inspect plugin-provided files before enabling any hook or command with shell access.

## Rules

- Keep plugin activation manual per machine.
- Prefer official or verified plugin sources.
- Do not commit plugin cache content.
- Do not commit machine-specific Claude settings or secrets.
