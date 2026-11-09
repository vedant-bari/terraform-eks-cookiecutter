#!/usr/bin/env bash
# DEPRECATED compatibility wrapper. Destroy plans only unless --destroy is explicit.
set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
echo "NOTICE: aws-eks/15-scripts is legacy. Delegating to guarded destroy workflow; backend bucket is excluded." >&2
exec bash "${SCRIPT_DIR}/../02-scripts/destroy-env.sh" "$@"
