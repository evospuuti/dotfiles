# AI Dots

Cross-platform dotfiles for Claude Code and Codex.

This repository is a small AI harness, not a full terminal or editor setup. It keeps shared prompts, skills, agent instructions, and MCP templates in one versioned source of truth.

## Quick Start

PowerShell:

```powershell
.\scripts\install.ps1 -DryRun
.\scripts\install.ps1 -Claude -Codex -Backup
```

Bash:

```bash
./scripts/install.sh --dry-run
./scripts/install.sh --claude --codex --backup
```

Default install behavior targets Claude and Codex agent configuration only. Shell and Git files require explicit flags.

## Layout

- `agents/` shared prompts and skills.
- `config/claude/` Claude-specific instructions, commands, plugin notes, subagent templates, hook templates, settings templates, and MCP templates.
- `config/codex/` Codex-specific instructions, config templates, and MCP templates.
- `scripts/` cross-platform install and check scripts.
- `docs/` install, platform, MCP, secrets, agent loop, and LLM-readable usage notes.
