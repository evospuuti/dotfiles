#!/usr/bin/env bash
set -euo pipefail

if command -v claude >/dev/null 2>&1; then
  claude --version >/dev/null
  claude plugin --help >/dev/null
  claude agents --help >/dev/null
  claude mcp --help >/dev/null
else
  printf 'Skipping Claude live surface checks: claude not found in Linux PATH.\n'
fi

if command -v codex >/dev/null 2>&1; then
  codex --version >/dev/null
  codex plugin --help >/dev/null
  codex mcp --help >/dev/null
  codex exec --help >/dev/null
else
  printf 'Skipping Codex live surface checks: codex not found in Linux PATH.\n'
fi

if command -v coderabbit >/dev/null 2>&1; then
  coderabbit --version >/dev/null
else
  printf 'Skipping CodeRabbit live surface checks: coderabbit not found in Linux PATH.\n'
fi

printf 'Linux live surface checks completed.\n'
