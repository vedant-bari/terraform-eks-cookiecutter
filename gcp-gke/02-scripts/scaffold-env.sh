#!/usr/bin/env bash
# Explicitly regenerate Terragrunt files from YAML/templates. This writes files.
set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
GCP_GKE_DIR="${REPO_ROOT}/gcp-gke"
[[ $# -eq 3 && "$3" == "--write" ]] || {
  echo "Usage: bash gcp-gke/02-scripts/scaffold-env.sh <client> <environment> --write" >&2
  echo "This command writes generated Terragrunt files; review the resulting diff." >&2
  exit 2
}
CLIENT="$1"; ENV="$2"
[[ "$CLIENT" =~ ^[a-z0-9][a-z0-9-]*$ && "$ENV" =~ ^[a-z0-9][a-z0-9-]*$ ]] || {
  echo "ERROR: client and environment must be lowercase alphanumeric/hyphen identifiers." >&2; exit 2;
}
CONFIG="${GCP_GKE_DIR}/01-config/clients/${CLIENT}/${ENV}/infra/${ENV}.yaml"
[[ -f "$CONFIG" ]] || { echo "ERROR: Missing config: $CONFIG" >&2; exit 1; }
python3 "${GCP_GKE_DIR}/02-scripts/scaffolding/02-scaffold_client.py" "$CONFIG"
python3 "${GCP_GKE_DIR}/02-scripts/scaffolding/03-scaffold_jenkins.py" "$CONFIG"
python3 "${GCP_GKE_DIR}/02-scripts/scaffolding/04-scaffold_apps.py" "$CONFIG"
echo "Scaffolding complete. Review git diff before using generated files."
