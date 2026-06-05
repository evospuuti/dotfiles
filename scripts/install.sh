#!/usr/bin/env bash
set -euo pipefail

DRY_RUN=false
BACKUP=false
LIST_PROMPTS=false
INSTALL_CLAUDE=false
INSTALL_CODEX=false
INSTALL_GIT=false
INSTALL_SHELL=false
INSTALL_ALL=false
SCOPE_SELECTED=false

SELECTED_PROMPTS=()
PROMPT_NAMES=()
PROMPTS_TO_INSTALL=()
declare -A PROMPT_FILES=()
PROMPTS_LOADED=false

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PROMPT_REGISTRY="$REPO_ROOT/agents/prompts/registry.yaml"

timestamp() {
  date +"%Y%m%d%H%M%S"
}

usage() {
  cat <<'USAGE'
Usage: scripts/install.sh [options]

Install selected ai-dots configuration files into $HOME.

Options:
  --claude           Install Claude configuration, prompts, and skills.
  --codex            Install Codex configuration, prompts, and skills.
  --git              Install Git configuration templates.
  --shell            Install shell helper files.
  --all              Install Claude, Codex, Git, and shell files.
  --dry-run          Print planned actions without writing anything.
  --backup           Move existing targets to .bak.<timestamp> before copying.
  --list-prompts     List registered prompt names and exit.
  --prompt NAME      Install only the named prompt. Repeat to select multiple.
  -h, --help         Show this help.

If no install-scope flags are passed, Claude and Codex are installed.
USAGE
}

die() {
  printf 'Error: %s\n' "$*" >&2
  exit 1
}

require_home() {
  if [[ -z "${HOME:-}" ]]; then
    die "HOME must not be empty."
  fi

  if [[ "$HOME" == "/" ]]; then
    die "HOME must not be filesystem root."
  fi
}

run_action() {
  local description="$1"
  shift

  if "$DRY_RUN"; then
    printf '[dry-run] %s\n' "$description"
  else
    "$@"
  fi
}

trim_yaml_value() {
  local value="$1"

  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"

  if ((${#value} >= 2)); then
    local first="${value:0:1}"
    local last="${value: -1}"
    if [[ ("$first" == '"' && "$last" == '"') || ("$first" == "'" && "$last" == "'") ]]; then
      value="${value:1:${#value}-2}"
    fi
  fi

  printf '%s' "$value"
}

load_prompts() {
  if "$PROMPTS_LOADED"; then
    return
  fi

  [[ -f "$PROMPT_REGISTRY" ]] || die "Prompt registry not found: $PROMPT_REGISTRY"

  local current_name=""
  local prompt_file=""
  local raw_line=""
  local line=""

  while IFS= read -r raw_line || [[ -n "$raw_line" ]]; do
    line="${raw_line%$'\r'}"

    if [[ "$line" =~ ^[[:space:]]*-[[:space:]]+name:[[:space:]]*(.+)[[:space:]]*$ ]]; then
      current_name="$(trim_yaml_value "${BASH_REMATCH[1]}")"
    elif [[ -n "$current_name" && "$line" =~ ^[[:space:]]*file:[[:space:]]*(.+)[[:space:]]*$ ]]; then
      prompt_file="$(trim_yaml_value "${BASH_REMATCH[1]}")"
      PROMPT_NAMES+=("$current_name")
      PROMPT_FILES["$current_name"]="$prompt_file"
      current_name=""
    fi
  done <"$PROMPT_REGISTRY"

  PROMPTS_LOADED=true
}

list_prompts() {
  load_prompts

  local prompt_name=""
  for prompt_name in "${PROMPT_NAMES[@]}"; do
    printf '%s\n' "$prompt_name"
  done
}

prompt_names_text() {
  load_prompts

  local output=""
  local prompt_name=""
  for prompt_name in "${PROMPT_NAMES[@]}"; do
    if [[ -n "$output" ]]; then
      output+=", "
    fi
    output+="$prompt_name"
  done

  printf '%s' "$output"
}

select_prompts() {
  load_prompts

  local prompt_name=""
  local -A seen_prompts=()
  if ((${#SELECTED_PROMPTS[@]} > 0)); then
    for prompt_name in "${SELECTED_PROMPTS[@]}"; do
      if [[ -n "${seen_prompts[$prompt_name]+x}" ]]; then
        continue
      fi
      seen_prompts["$prompt_name"]=true

      if [[ -z "${PROMPT_FILES[$prompt_name]+x}" ]]; then
        die "Prompt not found: $prompt_name. Available prompts: $(prompt_names_text)"
      fi
      PROMPTS_TO_INSTALL+=("$prompt_name")
    done
  else
    PROMPTS_TO_INSTALL=("${PROMPT_NAMES[@]}")
  fi
}

backup_existing() {
  local target="$1"
  local backup_target=""

  if [[ -e "$target" || -L "$target" ]]; then
    if "$BACKUP"; then
      backup_target="${target}.bak.$(timestamp)"
      run_action "Move existing $target -> $backup_target" mv "$target" "$backup_target"
    elif "$DRY_RUN"; then
      printf '[dry-run] Target already exists and would require --backup or manual removal: %s\n' "$target"
    else
      die "Target already exists: $target. Use --backup to move it aside before copying."
    fi
  fi
}

copy_file() {
  local source="$1"
  local target="$2"
  local parent=""

  [[ -f "$source" ]] || die "Source file not found: $source"
  parent="$(dirname "$target")"

  backup_existing "$target"
  run_action "Create directory $parent" mkdir -p "$parent"
  run_action "Copy file $source -> $target" cp "$source" "$target"
}

copy_dir() {
  local source="$1"
  local target="$2"
  local parent=""

  [[ -d "$source" ]] || die "Source directory not found: $source"
  parent="$(dirname "$target")"

  backup_existing "$target"
  run_action "Create directory $parent" mkdir -p "$parent"
  run_action "Copy directory $source -> $target" cp -R "$source" "$target"
}

install_prompts() {
  local target_root="$1"
  local prompt_name=""
  local prompt_file=""

  for prompt_name in "${PROMPTS_TO_INSTALL[@]}"; do
    prompt_file="${PROMPT_FILES[$prompt_name]}"
    copy_file "$REPO_ROOT/agents/prompts/$prompt_file" "$target_root/$prompt_name.md"
  done
}

install_skills() {
  local target_root="$1"
  local skill_dir=""
  local skill_name=""

  for skill_dir in "$REPO_ROOT"/agents/skills/*; do
    [[ -d "$skill_dir" ]] || continue
    skill_name="$(basename "$skill_dir")"
    copy_dir "$skill_dir" "$target_root/$skill_name"
  done
}

install_claude() {
  copy_file "$REPO_ROOT/config/claude/CLAUDE.md" "$HOME/.claude/CLAUDE.md"
  copy_file "$REPO_ROOT/config/claude/settings.json.template" "$HOME/.claude/settings.json.template"
  copy_file "$REPO_ROOT/config/claude/mcp.json.template" "$HOME/.claude/mcp.json.template"
  install_prompts "$HOME/.claude/commands"
  install_skills "$HOME/.claude/skills"
}

install_codex() {
  copy_file "$REPO_ROOT/config/codex/AGENTS.md" "$HOME/.codex/AGENTS.md"
  copy_file "$REPO_ROOT/config/codex/config.toml.template" "$HOME/.codex/config.toml.template"
  copy_file "$REPO_ROOT/config/codex/mcp.json.template" "$HOME/.codex/mcp.json.template"
  install_prompts "$HOME/.codex/prompts"
  install_skills "$HOME/.codex/skills"
}

install_git() {
  copy_file "$REPO_ROOT/config/git/gitconfig.template" "$HOME/.gitconfig.ai-dots"
  copy_file "$REPO_ROOT/config/git/gitignore_global" "$HOME/.gitignore_global"
}

install_shell() {
  copy_file "$REPO_ROOT/config/shell/aliases.sh" "$HOME/.config/ai-dots/aliases.sh"
  copy_file "$REPO_ROOT/config/shell/env.sh" "$HOME/.config/ai-dots/env.sh"
}

while (($# > 0)); do
  case "$1" in
    --claude)
      INSTALL_CLAUDE=true
      SCOPE_SELECTED=true
      ;;
    --codex)
      INSTALL_CODEX=true
      SCOPE_SELECTED=true
      ;;
    --git)
      INSTALL_GIT=true
      SCOPE_SELECTED=true
      ;;
    --shell)
      INSTALL_SHELL=true
      SCOPE_SELECTED=true
      ;;
    --all)
      INSTALL_ALL=true
      SCOPE_SELECTED=true
      ;;
    --dry-run)
      DRY_RUN=true
      ;;
    --backup)
      BACKUP=true
      ;;
    --list-prompts)
      LIST_PROMPTS=true
      ;;
    --prompt)
      shift
      if (($# == 0)); then
        printf 'Error: --prompt requires a prompt name.\n' >&2
        usage >&2
        exit 1
      fi
      SELECTED_PROMPTS+=("$1")
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    *)
      printf 'Error: unknown option: %s\n' "$1" >&2
      usage >&2
      exit 1
      ;;
  esac
  shift
done

if "$LIST_PROMPTS"; then
  list_prompts
  exit 0
fi

require_home

if "$INSTALL_ALL"; then
  INSTALL_CLAUDE=true
  INSTALL_CODEX=true
  INSTALL_GIT=true
  INSTALL_SHELL=true
elif ! "$SCOPE_SELECTED"; then
  INSTALL_CLAUDE=true
  INSTALL_CODEX=true
fi

select_prompts

if "$INSTALL_CLAUDE"; then
  install_claude
fi

if "$INSTALL_CODEX"; then
  install_codex
fi

if "$INSTALL_GIT"; then
  install_git
fi

if "$INSTALL_SHELL"; then
  install_shell
fi
