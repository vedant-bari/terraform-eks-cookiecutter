#!/usr/bin/env bash
# Backwards-compatible entry point. Deployment is plan-only; apply is separate.
set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ $# -gt 0 && "$1" == "--help" ]]; then
  echo "Use plan-env.sh to create reviewed plans, then apply-env.sh to apply saved plans."
  exit 0
fi
exec "${SCRIPT_DIR}/plan-env.sh" "$@"
