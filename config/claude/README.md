# Claude Adapter

Claude-specific files live here. Shared prompts and skills stay under `agents/`.

Install target examples:

- `CLAUDE.md` -> `~/.claude/CLAUDE.md`
- selected prompts -> `~/.claude/commands`
- selected skills -> `~/.claude/skills`
- settings template -> `~/.claude/settings.json.template`
- MCP template -> `~/.claude/mcp.json.template`
- plugin notes -> documentation only
- subagent templates -> `~/.claude/agents`
- hook template snippets -> reviewed snippets for `~/.claude/settings.json`

Plugin installation, hook activation, and subagent installation stay manual. Review each file before copying it into a live Claude directory.

`settings.json.template` is a minimal starting point, not a complete security policy. Keep destructive command protection in hooks, Git guardrails, and human review as well.
