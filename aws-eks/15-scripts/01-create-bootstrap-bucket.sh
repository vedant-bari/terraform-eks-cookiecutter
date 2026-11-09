#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
echo "NOTICE: use aws-eks/02-scripts/bootstrap/create-state-bucket.sh." >&2
exec bash "${SCRIPT_DIR}/../02-scripts/bootstrap/create-state-bucket.sh" "$@"
