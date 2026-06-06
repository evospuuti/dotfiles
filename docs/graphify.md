# Graphify

Graphify is an optional external CLI and assistant skill for creating a queryable knowledge graph from a repository.

Reference: https://github.com/safishamsi/graphify

## Why Include It

Use Graphify when a repository question depends on cross-file relationships, architecture, SQL schemas, infrastructure, docs, or generated call-flow diagrams. It is useful for large-codebase orientation before deeper Claude Code or Codex work.

## Install

The upstream package name is `graphifyy`; the CLI command is `graphify`.

```powershell
uv tool install graphifyy
```

Alternative:

```bash
pipx install graphifyy
```

Then install assistant integration manually if desired:

```bash
graphify install --project
graphify install --project --platform codex
```

Do not make Graphify a required dependency of this dotfiles repo. Keep it opt-in per machine or per project.

## Usage

From a repository root:

```bash
graphify .
graphify export callflow-html
```

On PowerShell, use:

```powershell
graphify .
```

Generated files live under `graphify-out/`, which is ignored by this repository.

## Safety

- Do not commit `graphify-out/`.
- Do not include secrets, private MCP files, local paths, or live assistant config in graph reports.
- Prefer querying an existing graph before reading broad file sets.
- Review generated reports before sharing them.
