#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TEMP_HOME="$(mktemp -d)"
SHELL_HOME="$(mktemp -d)"

cleanup() {
  rm -rf "$TEMP_HOME" "$SHELL_HOME"
}
trap cleanup EXIT

assert_file() {
  local path="$1"
  [[ -f "$path" ]] || {
    printf 'Expected file missing: %s\n' "$path" >&2
    exit 1
  }
}

assert_no_file() {
  local path="$1"
  [[ ! -f "$path" ]] || {
    printf 'Unexpected file exists: %s\n' "$path" >&2
    exit 1
  }
}

HOME="$TEMP_HOME" "$REPO_ROOT/scripts/install.sh" --claude --codex --prompt plan

assert_file "$TEMP_HOME/.claude/CLAUDE.md"
assert_file "$TEMP_HOME/.claude/commands/plan.md"
assert_no_file "$TEMP_HOME/.claude/commands/fix-ci.md"
assert_file "$TEMP_HOME/.codex/AGENTS.md"
assert_file "$TEMP_HOME/.codex/prompts/plan.md"
assert_no_file "$TEMP_HOME/.codex/prompts/fix-ci.md"

assert_no_file "$TEMP_HOME/.claude/agents/code-reviewer.md"
assert_no_file "$TEMP_HOME/.claude/settings.json"
assert_no_file "$TEMP_HOME/.codex/config.toml"

HOME="$TEMP_HOME" "$REPO_ROOT/scripts/install.sh" --dry-run --claude >/dev/null

HOME="$SHELL_HOME" "$REPO_ROOT/scripts/install.sh" --shell
assert_file "$SHELL_HOME/.config/ai-dots/aliases.sh"
assert_file "$SHELL_HOME/.config/ai-dots/env.sh"

printf 'Linux install tests passed.\n'
