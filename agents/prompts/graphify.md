# graphify

Use Graphify when codebase structure, cross-file relationships, or architecture questions are better answered through a generated knowledge graph than by reading files one by one.

Prefer this order:

1. If `graphify-out/graph.json` already exists, query or inspect the existing graph first.
2. If no graph exists and the user asked for graph-backed analysis, run `graphify .` from the repository root.
3. Use `graphify export callflow-html` when a readable architecture page with call-flow diagrams is useful.

Safety rules:

- Do not commit `graphify-out/`.
- Do not include secrets, private paths, or local MCP config in reports.
- On PowerShell, use `graphify .`; do not use `/graphify .`.
- For Codex, remember that Graphify uses `$graphify` style invocation in assistant prompts.

If Graphify is not installed, cite `docs/graphify.md` and suggest the manual install command instead of inventing output.
