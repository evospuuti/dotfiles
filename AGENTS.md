# Agent Instructions

This repository manages Claude Code and Codex configuration.

Before editing:

- Read `README.md` and `docs/llms.md`.
- Keep changes scoped to Claude, Codex, shared prompts, skills, installers, or documentation.
- Do not add real secrets, tokens, local machine paths, personal Git identity, signing keys, or private MCP files.
- Do not overwrite user files in home-directory targets unless the install script is in backup mode or the user explicitly confirms.
- Treat MCP configuration as opt-in. Templates are tracked; real local MCP files are ignored.
- Verify changes with `scripts/check.ps1` on Windows and `scripts/check.sh` on Unix-like shells when available.
