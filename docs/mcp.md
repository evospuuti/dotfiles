# MCP

MCP servers extend Claude and Codex with external tools such as filesystem access, Git inspection, web fetching, memory, planning, or time lookup. In this repository, MCP is opt-in and tracked files are templates only.

## Template Locations

- Claude template: `config/claude/mcp.json.template`
- Codex template: `config/codex/mcp.json.template`

Copy a template into a local ignored file before adding real server commands or credentials.

## Local Ignored Files

Use ignored local locations for private MCP config, such as `config/claude/_local/` and `config/codex/_local/`. Keep only placeholder files like `.gitkeep` tracked in `_local` directories.

## Credentials

Do not put API keys, tokens, private paths, or account-specific secrets in tracked MCP templates. Use environment variables, local ignored files, or a secret manager. Templates should use placeholders such as `${EXAMPLE_API_KEY}`.

## Reference Server Warning

Reference MCP server names and packages can change, and some servers grant broad file or network access. Verify the source, pin versions when practical, and restrict server permissions to the smallest useful scope before enabling them locally.

## Example Server Profiles

- `filesystem`: read or write selected local paths; restrict roots carefully.
- `git`: inspect repository state and history.
- `fetch`: retrieve web content when network use is allowed.
- `memory`: store local notes or durable context.
- `sequential-thinking`: help structure multi-step reasoning.
- `time`: provide current time and timezone data.

These profiles are examples, not active configuration.
