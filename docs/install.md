# Install

## PowerShell Dry-Run

Preview changes before touching local tool config:

```powershell
.\scripts\install.ps1 -DryRun
```

By default, install targets are Claude and Codex only. Git and shell config require explicit flags such as `-Git` and `-Shell`.

Use `-HomeRoot <path>` for isolated test installs. Do not point it at a real home directory unless you intend to install there.

## PowerShell Install

Install Claude and Codex config with backups enabled:

```powershell
.\scripts\install.ps1 -Claude -Codex -Backup
```

Add `-Git` to include `config/git/` templates. Add `-Shell` to include shell helpers.

## Bash Dry-Run

Preview changes on WSL2, Linux, or macOS:

```bash
./scripts/install.sh --dry-run
```

By default, install targets are Claude and Codex only. Git and shell config require explicit flags such as `--git` and `--shell`.

## Bash Install

Install Claude and Codex config with backups enabled:

```bash
./scripts/install.sh --claude --codex --backup
```

Add `--git` to include `config/git/` templates. Add `--shell` to include shell helpers.

## Shell Helpers

Shell helpers are optional. The installer copies them under `~/.config/ai-dots/` and does not replace your live shell or PowerShell profile. Source the files manually from your profile when you want them active.

## Backup Behavior

Use backup mode when installing into an existing home directory. Existing destination files should be copied to a backup location before the installer writes, links, or replaces anything. Without backup mode, installers should fail or prompt instead of silently overwriting user files.

## Prompt Selection

Shared prompts live under `agents/prompts/`. Keep prompt selection explicit: install the base Claude and Codex agent files first, then enable or copy only the prompts needed for the current workflow.

## Claude Extras

Claude plugin notes, hook snippets, and subagent templates live under `config/claude/`. They are documentation and templates in this scaffold. The installer handles shared prompts, skills, and adapter config only.

Activate plugins, hooks, and subagents manually after reviewing the target machine and current Claude plugin marketplace.
