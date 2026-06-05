#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

"$REPO_ROOT/scripts/check.sh"
bash "$REPO_ROOT/tests/install.linux.test.sh"
bash "$REPO_ROOT/tests/live.linux.test.sh"

printf 'Linux test suite passed.\n'
