#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PROMPT_REGISTRY="$REPO_ROOT/agents/prompts/registry.yaml"
FAILURES=()
PYTHON_CMD=""
PYTHON_CMD_CHECKED=false

add_failure() {
  FAILURES+=("$1")
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

find_python_cmd() {
  if [[ "$PYTHON_CMD_CHECKED" == true ]]; then
    [[ -n "$PYTHON_CMD" ]] && printf '%s\n' "$PYTHON_CMD"
    return
  fi

  local candidate=""
  local major_version=""
  for candidate in python3 python; do
    if ! command -v "$candidate" >/dev/null 2>&1; then
      continue
    fi

    major_version="$("$candidate" -c 'import sys; print(sys.version_info[0])' 2>/dev/null || true)"
    if [[ "$major_version" == "3" ]]; then
      PYTHON_CMD="$candidate"
      break
    fi
  done

  PYTHON_CMD_CHECKED=true
  [[ -n "$PYTHON_CMD" ]] && printf '%s\n' "$PYTHON_CMD"
}

assert_required_files() {
  local required_files=(
    ".gitignore"
    "README.md"
    "AGENTS.md"
    "agents/AGENTS.md"
    "agents/prompts/README.md"
    "agents/prompts/registry.yaml"
    "agents/prompts/plan.md"
    "agents/prompts/fix-ci.md"
    "agents/prompts/gh-review.md"
    "agents/prompts/make-tests.md"
    "agents/prompts/html-report.md"
    "agents/prompts/youtube-transcript.md"
    "agents/prompts/excalidraw.md"
    "agents/prompts/subagent-review.md"
    "agents/prompts/agent-loop.md"
    "agents/prompts/graphify.md"
    "agents/skills/README.md"
    "agents/skills/agent-loop/SKILL.md"
    "agents/skills/code-review/SKILL.md"
    "agents/skills/diagnose/SKILL.md"
    "agents/skills/excalidraw/SKILL.md"
    "agents/skills/graphify/SKILL.md"
    "agents/skills/html-report/SKILL.md"
    "agents/skills/mcp-safety/SKILL.md"
    "agents/skills/subagent-review/SKILL.md"
    "agents/skills/tdd/SKILL.md"
    "agents/skills/youtube-transcript/SKILL.md"
    "config/claude/README.md"
    "config/claude/CLAUDE.md"
    "config/claude/plugins.md"
    "config/claude/agents/README.md"
    "config/claude/agents/code-reviewer.md"
    "config/claude/agents/researcher.md"
    "config/claude/agents/planner.md"
    "config/claude/agents/test-runner.md"
    "config/claude/hooks/README.md"
    "config/claude/hooks/settings.hooks.json.template"
    "config/claude/settings.json.template"
    "config/claude/mcp.json.template"
    "config/codex/README.md"
    "config/codex/AGENTS.md"
    "config/codex/config.toml.template"
    "config/codex/mcp.json.template"
    "config/git/gitconfig.template"
    "config/git/gitignore_global"
    "config/powershell/Microsoft.PowerShell_profile.ps1"
    "config/shell/aliases.sh"
    "config/shell/env.sh"
    "docs/install.md"
    "docs/agent-loops.md"
    "docs/graphify.md"
    "docs/llms.md"
    "docs/mcp.md"
    "docs/platforms.md"
    "docs/secrets.md"
    "scripts/install.ps1"
    "scripts/install.sh"
    "scripts/check.ps1"
    "scripts/check.sh"
    "scripts/test.ps1"
    "scripts/test.sh"
    "scripts/test-live.ps1"
    "scripts/test-complete.ps1"
    "tests/install.windows.test.ps1"
    "tests/install.linux.test.sh"
    "tests/live.surface.test.ps1"
    "tests/live.linux.test.sh"
    "tests/features.test.ps1"
    "tests/eval/README.md"
    "tests/eval/rubric.yaml"
    "tests/eval/run-eval.ps1"
    "tests/eval/score-eval.ps1"
    "tests/eval/scorer.test.ps1"
  )

  local relative_path=""
  for relative_path in "${required_files[@]}"; do
    if [[ ! -f "$REPO_ROOT/$relative_path" ]]; then
      add_failure "Missing required file: $REPO_ROOT/$relative_path"
    fi
  done
}

validate_json_templates() {
  local python_cmd=""
  if ! python_cmd="$(find_python_cmd)"; then
    printf 'Skipping JSON validation: no usable Python 3 found.\n'
    return
  fi

  local template=""
  while IFS= read -r -d '' template; do
    if ! "$python_cmd" -m json.tool "$template" >/dev/null; then
      add_failure "Invalid JSON template: $template"
    fi
  done < <(find "$REPO_ROOT" -path '*/.git/*' -prune -o -path '*/_local/*' -prune -o -type f -name '*.json.template' -print0)
}

validate_toml_template() {
  local toml_path="$REPO_ROOT/config/codex/config.toml.template"
  [[ -f "$toml_path" ]] || return

  local parsed_with_tomllib=false
  local python_cmd=""
  if python_cmd="$(find_python_cmd)"; then
    if "$python_cmd" - "$toml_path" <<'PY'
import sys

if sys.version_info < (3, 11):
    sys.exit(2)

import tomllib

with open(sys.argv[1], "rb") as template:
    tomllib.load(template)
PY
    then
      parsed_with_tomllib=true
    else
      local exit_code=$?
      if [[ "$exit_code" != "2" ]]; then
        add_failure "Invalid TOML template: $toml_path (Python tomllib exited with code $exit_code)"
        parsed_with_tomllib=true
      fi
    fi
  fi

  if [[ "$parsed_with_tomllib" == true ]]; then
    return
  fi

  local required_lines=(
    'approval_policy = "on-request"'
    'sandbox_mode = "workspace-write"'
    '[features]'
    'child_agents_md = true'
  )
  local required_line=""
  for required_line in "${required_lines[@]}"; do
    if ! grep -Fqx -- "$required_line" "$toml_path"; then
      add_failure "TOML template missing required literal line in $toml_path: $required_line"
    fi
  done
}

frontmatter_field() {
  local skill_file="$1"
  local field_name="$2"

  awk -v key="$field_name" '
    NR == 1 { next }
    /^---\r?$/ { exit }
    {
      line = $0
      sub(/\r$/, "", line)
      pattern = "^[[:space:]]*" key ":[[:space:]]*"
      if (line ~ pattern) {
        sub(pattern, "", line)
        print line
        exit
      }
    }
  ' "$skill_file"
}

validate_skill_frontmatter() {
  local skills_root="$REPO_ROOT/agents/skills"
  [[ -d "$skills_root" ]] || return

  local found_skill=false
  local skill_dir=""
  local skill_file=""
  local first_line=""
  local name_value=""
  local description_value=""

  shopt -s nullglob
  for skill_dir in "$skills_root"/*; do
    [[ -d "$skill_dir" ]] || continue
    found_skill=true
    skill_file="$skill_dir/SKILL.md"

    if [[ ! -f "$skill_file" ]]; then
      add_failure "Missing skill file: $skill_file"
      continue
    fi

    first_line="$(head -n 1 "$skill_file" | tr -d '\r')"
    if [[ "$first_line" != "---" ]]; then
      add_failure "Skill file must start with frontmatter delimiter: $skill_file"
      continue
    fi

    if ! awk 'NR > 1 && /^---\r?$/ { found = 1; exit } END { exit found ? 0 : 1 }' "$skill_file"; then
      add_failure "Skill file missing closing frontmatter delimiter: $skill_file"
      continue
    fi

    name_value="$(trim_yaml_value "$(frontmatter_field "$skill_file" "name")")"
    description_value="$(trim_yaml_value "$(frontmatter_field "$skill_file" "description")")"

    if [[ -z "$name_value" ]]; then
      add_failure "Skill frontmatter missing non-empty name: $skill_file"
    fi

    if [[ -z "$description_value" ]]; then
      add_failure "Skill frontmatter missing non-empty description: $skill_file"
    fi
  done
  shopt -u nullglob

  if [[ "$found_skill" == false ]]; then
    add_failure "No skill files found under: $skills_root"
  fi
}

parse_prompt_registry() {
  awk '
    function trim_yaml_value(value) {
      sub(/\r$/, "", value)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
      if (length(value) >= 2) {
        first = substr(value, 1, 1)
        last = substr(value, length(value), 1)
        if ((first == "\"" && last == "\"") || (first == "'"'"'" && last == "'"'"'")) {
          value = substr(value, 2, length(value) - 2)
        }
      }
      return value
    }

    function emit_entry() {
      if (name != "") {
        print name "\t" file "\t" tools
      }
      name = ""
      file = ""
      tools = ""
      in_tools = 0
    }

    {
      line = $0
      sub(/\r$/, "", line)

      if (line ~ /^[[:space:]]*-[[:space:]]+name:[[:space:]]*/) {
        emit_entry()
        value = line
        sub(/^[[:space:]]*-[[:space:]]+name:[[:space:]]*/, "", value)
        name = trim_yaml_value(value)
        next
      }

      if (name == "") {
        next
      }

      if (line ~ /^[[:space:]]*file:[[:space:]]*/) {
        value = line
        sub(/^[[:space:]]*file:[[:space:]]*/, "", value)
        file = trim_yaml_value(value)
        next
      }

      if (line ~ /^[[:space:]]*tools:[[:space:]]*$/) {
        in_tools = 1
        next
      }

      if (in_tools && line ~ /^[[:space:]]*-[[:space:]]+/) {
        value = line
        sub(/^[[:space:]]*-[[:space:]]+/, "", value)
        value = trim_yaml_value(value)
        tools = tools "," value ","
        next
      }
    }

    END {
      emit_entry()
    }
  ' "$PROMPT_REGISTRY"
}

validate_prompt_registry() {
  [[ -f "$PROMPT_REGISTRY" ]] || return

  local prompt_count=0
  local prompt_name=""
  local prompt_file=""
  local prompt_tools=""
  local prompt_path=""

  while IFS=$'\t' read -r prompt_name prompt_file prompt_tools; do
    ((prompt_count += 1))

    if [[ -z "$prompt_name" ]]; then
      add_failure "Prompt registry entry has an empty name: $PROMPT_REGISTRY"
    elif [[ ! "$prompt_name" =~ ^[a-z0-9][a-z0-9-]*$ ]]; then
      add_failure "Prompt registry entry has invalid name '$prompt_name': $PROMPT_REGISTRY"
    fi

    if [[ -z "$prompt_file" ]]; then
      add_failure "Prompt registry entry '$prompt_name' missing file field: $PROMPT_REGISTRY"
    elif [[ ! "$prompt_file" =~ ^[a-z0-9][a-z0-9-]*\.md$ ]]; then
      add_failure "Prompt registry entry '$prompt_name' has invalid file '$prompt_file': $PROMPT_REGISTRY"
    else
      prompt_path="$REPO_ROOT/agents/prompts/$prompt_file"
      if [[ ! -f "$prompt_path" ]]; then
        add_failure "Prompt registry references missing file: $prompt_path (prompt: $prompt_name, registry: $PROMPT_REGISTRY)"
      fi
    fi

    if [[ "$prompt_tools" != *",claude,"* ]]; then
      add_failure "Prompt registry entry '$prompt_name' missing tool 'claude': $PROMPT_REGISTRY"
    fi

    if [[ "$prompt_tools" != *",codex,"* ]]; then
      add_failure "Prompt registry entry '$prompt_name' missing tool 'codex': $PROMPT_REGISTRY"
    fi
  done < <(parse_prompt_registry)

  if ((prompt_count == 0)); then
    add_failure "No prompts registered in: $PROMPT_REGISTRY"
  fi
}

source_files_for_secret_scan() {
  if command -v git >/dev/null 2>&1 && git -C "$REPO_ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    local relative_path=""
    while IFS= read -r -d '' relative_path; do
      case "$relative_path" in
        .git/* | */_local/* | _local/*)
          continue
          ;;
      esac
      [[ -f "$REPO_ROOT/$relative_path" ]] && printf '%s\0' "$REPO_ROOT/$relative_path"
    done < <(git -C "$REPO_ROOT" ls-files -z --cached --others --exclude-standard)
    return
  fi

  find "$REPO_ROOT" -path "$REPO_ROOT/.git" -prune -o -path '*/_local/*' -prune -o -type f -print0
}

scan_secret_patterns() {
  local pattern_openai="s""k-"
  local pattern_github="g""hp_"
  local pattern_slack="x""oxb-"
  local pattern_pem
  pattern_pem="$(printf '%sBEGIN' '-----')"

  local patterns=("$pattern_openai" "$pattern_github" "$pattern_slack" "$pattern_pem")
  local labels=("OpenAI-style key prefix" "GitHub token prefix" "Slack bot token prefix" "PEM block header")

  local file_path=""
  local index=0
  local grep_status=0
  while IFS= read -r -d '' file_path; do
    for index in "${!patterns[@]}"; do
      set +e
      grep -F -q -- "${patterns[$index]}" "$file_path"
      grep_status=$?
      set -e

      case "$grep_status" in
        0)
          add_failure "Secret-like pattern (${labels[$index]}) found in: $file_path"
          break
          ;;
        1)
          ;;
        *)
          add_failure "Could not scan file for secrets (${labels[$index]}): $file_path (grep exited with code $grep_status)"
          break
          ;;
      esac
    done
  done < <(source_files_for_secret_scan)
}

scan_live_config_files() {
  local relative_path=""
  if command -v git >/dev/null 2>&1 && git -C "$REPO_ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    while IFS= read -r -d '' relative_path; do
      case "$relative_path" in
        _local/.gitkeep | */_local/.gitkeep)
          ;;
        _local/* | */_local/*)
          add_failure "Files under _local must not be tracked: $relative_path"
          ;;
      esac

      case "$relative_path" in
        mcp.json | settings.json | config.toml | */mcp.json | */settings.json | */config.toml)
        add_failure "Live local config file must not be tracked or staged: $relative_path"
          ;;
      esac
    done < <(git -C "$REPO_ROOT" ls-files -z --cached)
    return
  fi

  local file_path=""
  while IFS= read -r -d '' file_path; do
    relative_path="${file_path#$REPO_ROOT/}"
    case "$relative_path" in
      mcp.json | settings.json | config.toml | */mcp.json | */settings.json | */config.toml)
        add_failure "Live local config file must not be tracked or staged: $relative_path"
        ;;
    esac
  done < <(source_files_for_secret_scan)
}

assert_required_files
validate_json_templates
validate_toml_template
validate_skill_frontmatter
validate_prompt_registry
scan_secret_patterns
scan_live_config_files

if ((${#FAILURES[@]} > 0)); then
  printf 'Repository check failed:\n' >&2
  failure=""
  for failure in "${FAILURES[@]}"; do
    printf ' - %s\n' "$failure" >&2
  done
  exit 1
fi

printf 'Repository check passed.\n'
