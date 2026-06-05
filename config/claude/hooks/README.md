# Claude Hooks

Hook templates are opt-in. Copy reviewed snippets into `~/.claude/settings.json` only after checking commands on the target machine.

## Rules

- Keep commands repo-local and deterministic.
- Prefer checks like `scripts/check.ps1` or `scripts/check.sh`.
- Do not run package installs, network calls, destructive Git commands, or secret readers in hooks.
- Keep hook output short.

## Template

`settings.hooks.json.template` is a placeholder shape. Replace the command with the local check you actually want before copying it into Claude settings.
