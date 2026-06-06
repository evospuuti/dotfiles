---
name: graphify
description: Use when the user wants graph-backed codebase understanding, architecture maps, cross-file relationship analysis, or Graphify setup for Claude Code or Codex.
---

# Graphify

Graphify is an optional external CLI and assistant skill for turning a project into a queryable knowledge graph.

Use it when:

- a question spans many files or layers;
- code, docs, SQL, infrastructure, or scripts need to be connected in one view;
- the user asks for Graphify, knowledge graphs, architecture maps, or call-flow diagrams.

Workflow:

1. Check whether `graphify-out/graph.json` or `graphify-out/GRAPH_REPORT.md` already exists.
2. If a graph exists, prefer querying or inspecting it before broad file reads.
3. If no graph exists and the user wants graph-backed analysis, run `graphify .` from the repository root.
4. For architecture output, run `graphify export callflow-html`.
5. Keep generated output under ignored `graphify-out/`.

Setup notes:

- The official PyPI package is `graphifyy`; the CLI command is `graphify`.
- Recommended install: `uv tool install graphifyy`.
- Project-scoped installs can be done with `graphify install --project` or `graphify install --project --platform codex`.
- On PowerShell, use `graphify .`, not `/graphify .`.

Do not commit generated graph output, secrets, private MCP files, local machine paths, or assistant-specific live config.
