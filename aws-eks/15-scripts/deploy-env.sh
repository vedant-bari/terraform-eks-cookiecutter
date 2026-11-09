#!/usr/bin/env bash
# DEPRECATED compatibility wrapper. New deploy entrypoint is plan-only.
set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
echo "NOTICE: aws-eks/15-scripts is legacy. Delegating to the safe plan-only workflow." >&2
exec bash "${SCRIPT_DIR}/../02-scripts/deploy-env.sh" "$@"
