#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TEMP_HOME="$(mktemp -d)"
SHELL_HOME="$(mktemp -d)"
BACKUP_HOME="$(mktemp -d)"

cleanup() {
  rm -rf "$TEMP_HOME" "$SHELL_HOME" "$BACKUP_HOME"
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
assert_file "$TEMP_HOME/.claude/skills/tdd/SKILL.md"
assert_file "$TEMP_HOME/.codex/skills/tdd/SKILL.md"

assert_no_file "$TEMP_HOME/.claude/agents/code-reviewer.md"
assert_no_file "$TEMP_HOME/.claude/settings.json"
assert_no_file "$TEMP_HOME/.claude/mcp.json"
assert_no_file "$TEMP_HOME/.codex/config.toml"
assert_no_file "$TEMP_HOME/.codex/mcp.json"
assert_no_file "$TEMP_HOME/.gitconfig.ai-dots"
assert_no_file "$TEMP_HOME/.gitignore_global"

HOME="$TEMP_HOME" "$REPO_ROOT/scripts/install.sh" --dry-run --claude >/dev/null

set +e
HOME="" "$REPO_ROOT/scripts/install.sh" --dry-run --claude >"$TEMP_HOME/empty-home.out" 2>&1
empty_home_status=$?
set -e
if [[ "$empty_home_status" == "0" ]] || ! grep -Fq 'HOME must not be empty' "$TEMP_HOME/empty-home.out"; then
  printf 'Expected empty HOME dry-run to fail with a clear error.\n' >&2
  cat "$TEMP_HOME/empty-home.out" >&2
  exit 1
fi

HOME="$SHELL_HOME" "$REPO_ROOT/scripts/install.sh" --shell
assert_file "$SHELL_HOME/.config/ai-dots/aliases.sh"
assert_file "$SHELL_HOME/.config/ai-dots/env.sh"

mkdir -p "$BACKUP_HOME/.claude"
printf 'sentinel-existing-claude\n' >"$BACKUP_HOME/.claude/CLAUDE.md"

set +e
HOME="$BACKUP_HOME" "$REPO_ROOT/scripts/install.sh" --claude --prompt plan >"$BACKUP_HOME/no-backup.out" 2>&1
no_backup_status=$?
set -e
if [[ "$no_backup_status" == "0" ]]; then
  printf 'Expected install without --backup to fail when target exists.\n' >&2
  exit 1
fi
if [[ "$(cat "$BACKUP_HOME/.claude/CLAUDE.md")" != "sentinel-existing-claude" ]]; then
  printf 'Install without backup changed existing target content.\n' >&2
  exit 1
fi

HOME="$BACKUP_HOME" "$REPO_ROOT/scripts/install.sh" --claude --prompt plan --backup
backup_count="$(find "$BACKUP_HOME/.claude" -maxdepth 1 -type f -name 'CLAUDE.md.bak.*' | wc -l | tr -d ' ')"
if [[ "$backup_count" != "1" ]]; then
  printf 'Expected one CLAUDE.md backup file. Found %s.\n' "$backup_count" >&2
  exit 1
fi
if grep -Fq 'sentinel-existing-claude' "$BACKUP_HOME/.claude/CLAUDE.md"; then
  printf 'Backup install did not replace target content.\n' >&2
  exit 1
fi

printf 'Linux install tests passed.\n'
