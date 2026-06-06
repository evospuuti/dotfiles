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
- `docs/` install, platform, MCP, secrets, Graphify, agent loop, and LLM-readable usage notes.

## Testing

Deterministic Windows tests:

```powershell
.\scripts\test.ps1
```

Live Windows CLI surface checks:

```powershell
.\scripts\test-live.ps1
```

Complete Windows harness checks:

```powershell
.\scripts\test-complete.ps1
```

Run real Claude and Codex model calls only when authenticated and willing to spend subscription or API budget:

```powershell
.\scripts\test-live.ps1 -RunModelCalls
.\scripts\test-complete.ps1 -RunModelCalls
```

Linux, WSL2, or macOS deterministic tests:

```bash
./scripts/test.sh
```

The test suites install into isolated temporary homes and verify prompt selection, Claude and Codex adapter files, skills, opt-in Claude extras, live config safety, backup behavior, CodeRabbit surface checks when available, and template validation. LLM output quality evals live under `tests/eval/` and require authenticated Claude Code or Codex CLI access.
