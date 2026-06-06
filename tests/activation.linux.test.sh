#!/usr/bin/env bash
set -euo pipefail

RUN_MODEL_CALLS=false
REQUIRE_CLAUDE=false
REQUIRE_CODEX=false
REQUIRE_GRAPHIFY=false

while (($# > 0)); do
  case "$1" in
    --run-model-calls)
      RUN_MODEL_CALLS=true
      ;;
    --require-claude)
      REQUIRE_CLAUDE=true
      ;;
    --require-codex)
      REQUIRE_CODEX=true
      ;;
    --require-graphify)
      REQUIRE_GRAPHIFY=true
      ;;
    *)
      printf 'Unknown option: %s\n' "$1" >&2
      exit 1
      ;;
  esac
  shift
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PROBE_SERVER="$REPO_ROOT/tests/fixtures/mcp/ai_dots_probe_server.py"
TEMP_HOME="$(mktemp -d)"
TEMP_ROOT="$(mktemp -d)"
FAILURES=()

cleanup() {
  rm -rf "$TEMP_HOME" "$TEMP_ROOT"
}
trap cleanup EXIT

add_failure() {
  FAILURES+=("$1")
}

assert_file() {
  if [[ ! -f "$1" ]]; then
    add_failure "Expected file: $1"
  fi
}

capture() {
  local output_file="$1"
  shift
  set +e
  "$@" >"$output_file" 2>&1
  local status=$?
  set -e
  return "$status"
}

assert_command_contains() {
  local label="$1"
  local pattern="$2"
  shift 2
  local output_file="$TEMP_ROOT/${label//[^a-zA-Z0-9]/_}.out"
  if ! capture "$output_file" "$@"; then
    add_failure "$label failed: $(cat "$output_file")"
    return
  fi
  if ! grep -Eiq "$pattern" "$output_file"; then
    add_failure "$label missing pattern $pattern: $(cat "$output_file")"
  fi
}

HOME="$TEMP_HOME" "$REPO_ROOT/scripts/install.sh" --all

for relative_path in \
  ".claude/CLAUDE.md" \
  ".claude/commands/graphify.md" \
  ".claude/skills/graphify/SKILL.md" \
  ".codex/AGENTS.md" \
  ".codex/prompts/graphify.md" \
  ".codex/skills/graphify/SKILL.md" \
  ".gitconfig.ai-dots" \
  ".gitignore_global" \
  ".config/ai-dots/aliases.sh" \
  ".config/ai-dots/env.sh"; do
  assert_file "$TEMP_HOME/$relative_path"
done

if command -v claude >/dev/null 2>&1; then
  assert_command_contains "claude version" "Claude Code" claude --version
  assert_command_contains "claude plugin list setup" "claude-code-setup" claude plugin list
  assert_command_contains "claude plugin list superpowers" "superpowers" claude plugin list
else
  if "$REQUIRE_CLAUDE"; then
    add_failure "claude command not found."
  else
    printf 'Skipping Claude activation checks: claude not found in Linux PATH.\n'
  fi
fi

if command -v codex >/dev/null 2>&1; then
  assert_command_contains "codex version" "codex" codex --version
  assert_command_contains "codex plugin marketplace" "add|upgrade|remove" codex plugin marketplace --help
  mkdir -p "$TEMP_ROOT/codex-home"
  CODEX_HOME="$TEMP_ROOT/codex-home" codex mcp add ai_dots_probe -- python3 "$PROBE_SERVER" >/dev/null
  CODEX_HOME="$TEMP_ROOT/codex-home" codex mcp list --json >"$TEMP_ROOT/codex-mcp-list.json"
  if ! grep -Fq "ai_dots_probe" "$TEMP_ROOT/codex-mcp-list.json"; then
    add_failure "Codex MCP list missing ai_dots_probe."
  fi
else
  if "$REQUIRE_CODEX"; then
    add_failure "codex command not found."
  else
    printf 'Skipping Codex activation checks: codex not found in Linux PATH.\n'
  fi
fi

if command -v coderabbit >/dev/null 2>&1; then
  assert_command_contains "coderabbit version" "." coderabbit --version
else
  printf 'Skipping CodeRabbit activation checks: coderabbit not found in Linux PATH.\n'
fi

if command -v graphify >/dev/null 2>&1; then
  graph_root="$TEMP_ROOT/graphify-project"
  mkdir -p "$graph_root"
  printf 'def probe(): return "graphify-ok"\n' >"$graph_root/probe.py"
  assert_command_contains "graphify install help" "Platforms" graphify install --help
  if ! (cd "$graph_root" && graphify . >"$TEMP_ROOT/graphify.out" 2>&1); then
    add_failure "graphify . failed: $(cat "$TEMP_ROOT/graphify.out")"
  elif [[ ! -d "$graph_root/graphify-out" ]]; then
    add_failure "Graphify did not create graphify-out/."
  fi
else
  if "$REQUIRE_GRAPHIFY"; then
    add_failure "graphify command not found."
  else
    printf 'Skipping Graphify activation checks: graphify not found in Linux PATH.\n'
  fi
fi

if "$RUN_MODEL_CALLS"; then
  if command -v claude >/dev/null 2>&1; then
    claude_mcp="$TEMP_ROOT/claude-mcp.json"
    python3 - "$claude_mcp" "$PROBE_SERVER" <<'PY'
import json
import sys

path, server = sys.argv[1], sys.argv[2]
with open(path, "w", encoding="utf-8") as handle:
    json.dump({"mcpServers": {"ai_dots_probe": {"command": "python3", "args": [server]}}}, handle)
PY
    if ! claude -p 'Use the MCP tool named mcp__ai_dots_probe__probe exactly once. Return exactly the tool result text and nothing else.' \
      --model sonnet \
      --permission-mode dontAsk \
      --allowedTools mcp__ai_dots_probe__probe \
      --mcp-config "$claude_mcp" \
      --strict-mcp-config \
      --max-budget-usd 0.50 \
      --no-session-persistence >"$TEMP_ROOT/claude-mcp.out" 2>&1; then
      add_failure "Claude MCP model call failed: $(cat "$TEMP_ROOT/claude-mcp.out")"
    elif ! grep -Fq "ai-dots-mcp-ok" "$TEMP_ROOT/claude-mcp.out"; then
      add_failure "Claude MCP model call missing marker: $(cat "$TEMP_ROOT/claude-mcp.out")"
    fi
  fi

  if command -v codex >/dev/null 2>&1; then
    codex_config="${CODEX_HOME:-$HOME/.codex}/config.toml"
    codex_backup=""
    if [[ -f "$codex_config" ]]; then
      codex_backup="$codex_config.ai-dots-activation.bak"
      cp "$codex_config" "$codex_backup"
    fi
    codex mcp remove ai_dots_probe >/dev/null 2>&1 || true
    if ! codex mcp add ai_dots_probe -- python3 "$PROBE_SERVER" >"$TEMP_ROOT/codex-mcp-add.out" 2>&1; then
      add_failure "Codex MCP add failed: $(cat "$TEMP_ROOT/codex-mcp-add.out")"
    elif ! codex exec -C "$REPO_ROOT" --sandbox read-only -c 'approval_policy="never"' --ephemeral \
      -c "mcp_servers.ai_dots_probe.default_tools_approval_mode='approve'" \
      'Use the MCP tool mcp__ai_dots_probe__probe exactly once. Return exactly the tool result text and nothing else.' >"$TEMP_ROOT/codex-mcp.out" 2>&1; then
      add_failure "Codex MCP model call failed: $(cat "$TEMP_ROOT/codex-mcp.out")"
    elif ! grep -Fq "ai-dots-mcp-ok" "$TEMP_ROOT/codex-mcp.out"; then
      add_failure "Codex MCP model call missing marker: $(cat "$TEMP_ROOT/codex-mcp.out")"
    fi
    codex mcp remove ai_dots_probe >/dev/null 2>&1 || true
    if [[ -n "$codex_backup" && -f "$codex_backup" ]]; then
      cp "$codex_backup" "$codex_config"
      rm -f "$codex_backup"
    fi
  fi
fi

if ((${#FAILURES[@]} > 0)); then
  printf 'Linux activation tests failed:\n' >&2
  for failure in "${FAILURES[@]}"; do
    printf ' - %s\n' "$failure" >&2
  done
  exit 1
fi

printf 'Linux activation tests passed.\n'
