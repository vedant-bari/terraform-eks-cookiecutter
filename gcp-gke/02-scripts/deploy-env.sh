#!/usr/bin/env bash
# Backward-compatible planning entry point. This script never applies changes.
set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
echo "NOTICE: deploy-env.sh is now plan-only. Use apply-env.sh with reviewed saved plans to deploy."
exec bash "${SCRIPT_DIR}/plan-env.sh" "$@"
