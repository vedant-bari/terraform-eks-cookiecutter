#!/usr/bin/env bash
# Read-only static validation. Does not run scaffolders, init, plan, apply, or destroy.
set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
python3 "${SCRIPT_DIR}/validation/validate_repo.py"
