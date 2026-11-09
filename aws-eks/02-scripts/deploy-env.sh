#!/usr/bin/env bash
# Backwards-compatible entry point. Deployment is plan-only; apply is separate.
set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec bash "${SCRIPT_DIR}/plan-env.sh" "$@"
