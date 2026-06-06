#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

bash "$REPO_ROOT/tests/activation.linux.test.sh" "$@"

printf 'Linux activation harness tests passed.\n'
