# LLM Usage

## Read Order

Agents should read files in this order:

1. `README.md`
2. `AGENTS.md`
3. `agents/AGENTS.md`
4. The relevant tool adapter README, such as `config/claude/README.md` or `config/codex/README.md`
5. `docs/install.md`
6. `docs/mcp.md`
7. `docs/secrets.md`
8. When relevant, `config/claude/plugins.md`, `config/claude/hooks/README.md`, `config/claude/agents/README.md`, and `docs/agent-loops.md`

## Files Agents May Edit

Agents may edit repository documentation, shared agent instructions, prompt and skill templates, Claude and Codex adapter templates, installer scripts, check scripts, and test fixtures when the current task explicitly requires it.

Always keep edits scoped to the active task. Preserve user changes and do not rewrite unrelated files.

Agents may update plugin notes, hook templates, and subagent templates. They must not activate hooks, install plugins, or copy subagents into a live home directory unless the user explicitly asks for local setup.

## Files And Paths Agents Must Not Create

Agents must not create real secret files, private MCP configs, host-specific config, personal Git identity, SSH keys, signing keys, or files containing API keys or tokens.

Do not create tracked files under `_local` directories except `.gitkeep`. Do not create real `mcp.json`, `settings.json`, `config.toml`, `.env`, `.env.*`, or home-directory target files from templates unless the user explicitly asks for local setup outside the repository.

## Verification

Run the platform-appropriate check before reporting completion:

```powershell
./scripts/check.ps1
```

```bash
./scripts/check.sh
```
