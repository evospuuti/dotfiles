---
name: mcp-safety
description: Use when adding, reviewing, or enabling MCP server configuration.
---

# MCP Safety

Before enabling an MCP server:

1. Identify what data and tools the server can access.
2. Check whether it reads secrets, files, Git state, browsers, or network resources.
3. Keep credentials in ignored local files or environment variables.
4. Prefer least-privilege paths and read-only modes where possible.
5. Treat reference servers as examples that still need a local threat review.
