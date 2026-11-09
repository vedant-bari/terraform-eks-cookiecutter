#!/usr/bin/env bash
# Read-only repository validation. No scaffold, init, plan, apply, import, or destroy.
set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
python3 "${SCRIPT_DIR}/validate_repo.py"
