#!/usr/bin/env bash
# Create reviewed, saved Terraform plans only. This script never applies changes.
set -Eeuo pipefail
umask 077

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
GCP_GKE_DIR="${REPO_ROOT}/gcp-gke"
LAYERS=(01-network 02-gke 03-artifact-registry 04-storage 06-jenkins 07-applications)

usage() {
  echo "Usage: bash gcp-gke/02-scripts/plan-env.sh <client> <environment> [--plan-dir <absolute-or-relative-path>]"
}

[[ $# -ge 2 ]] || { usage; exit 2; }
CLIENT="$1"; ENV="$2"; shift 2
[[ "$CLIENT" =~ ^[a-z0-9][a-z0-9-]*$ && "$ENV" =~ ^[a-z0-9][a-z0-9-]*$ ]] || {
  echo "ERROR: client and environment must be lowercase alphanumeric/hyphen identifiers." >&2; exit 2;
}

PLAN_DIR=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --plan-dir)
      [[ $# -ge 2 && -n "$2" ]] || { echo "ERROR: --plan-dir requires a path." >&2; exit 2; }
      PLAN_DIR="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "ERROR: Unknown argument: $1" >&2; usage; exit 2 ;;
  esac
done

CONFIG_FILE="${GCP_GKE_DIR}/01-config/clients/${CLIENT}/${ENV}/infra/${ENV}.yaml"
LIVE_DIR="${GCP_GKE_DIR}/04-live/clients/${CLIENT}/${ENV}"
[[ -f "$CONFIG_FILE" ]] || { echo "ERROR: Missing environment config: $CONFIG_FILE" >&2; exit 1; }
[[ -d "$LIVE_DIR" ]] || { echo "ERROR: Missing live directory: $LIVE_DIR" >&2; exit 1; }
command -v terragrunt >/dev/null || { echo "ERROR: terragrunt is not installed." >&2; exit 1; }
command -v python3 >/dev/null || { echo "ERROR: python3 is not installed." >&2; exit 1; }

cd "$REPO_ROOT"
BRANCH="$(git branch --show-current)"
COMMIT="$(git rev-parse HEAD)"
[[ -n "$BRANCH" ]] || { echo "ERROR: Detached HEAD; use a named review branch." >&2; exit 1; }
[[ -z "$(git status --porcelain)" ]] || {
  echo "ERROR: Working tree is not clean. Commit or otherwise resolve local changes before planning." >&2; exit 1;
}

# Backend bucket must already exist. No bucket creation or state import is performed here.
STATE_BUCKET="$(python3 - "$CONFIG_FILE" <<'PY'
import sys, yaml
with open(sys.argv[1], encoding="utf-8") as f:
    data = yaml.safe_load(f) or {}
print((data.get("bootstrap") or {}).get("state_bucket_name", ""))
PY
)"
[[ -n "$STATE_BUCKET" ]] || { echo "ERROR: bootstrap.state_bucket_name is empty in $CONFIG_FILE" >&2; exit 1; }
echo "Remote-state bucket configured as gs://${STATE_BUCKET}."
echo "This workflow does not create the bucket or import it into Terraform state."

if [[ -z "$PLAN_DIR" ]]; then
  PLAN_DIR="${TMPDIR:-/tmp}/gke-plans-${CLIENT}-${ENV}-$(date -u +%Y%m%dT%H%M%SZ)"
fi
[[ "$PLAN_DIR" = /* ]] || PLAN_DIR="${REPO_ROOT}/${PLAN_DIR}"
mkdir -p "$PLAN_DIR"
PLAN_DIR="$(cd "$PLAN_DIR" && pwd)"
case "$PLAN_DIR/" in
  "$REPO_ROOT/"*) echo "ERROR: Plan directory must be outside the repository (plans may contain secrets)." >&2; exit 1 ;;
esac
[[ -z "$(find "$PLAN_DIR" -mindepth 1 -maxdepth 1 -print -quit)" ]] || {
  echo "ERROR: Plan directory must be empty: $PLAN_DIR" >&2; exit 1;
}

MANIFEST="${PLAN_DIR}/manifest.txt"
{
  printf 'operation=plan\nclient=%s\nenvironment=%s\nbranch=%s\ncommit=%s\ncreated_utc=%s\n' \
    "$CLIENT" "$ENV" "$BRANCH" "$COMMIT" "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
} > "$MANIFEST"
chmod 600 "$MANIFEST"

for layer in "${LAYERS[@]}"; do
  layer_dir="${LIVE_DIR}/${layer}"
  [[ -d "$layer_dir" ]] || { echo "ERROR: Required live layer is missing: $layer_dir" >&2; exit 1; }
  plan_file="${PLAN_DIR}/${layer}.tfplan"
  echo
  echo "===== PLAN: ${CLIENT}/${ENV}/${layer} ====="
  (
    cd "$layer_dir"
    terragrunt init
    terragrunt run -- plan -out="$plan_file"
  )
  [[ -s "$plan_file" ]] || { echo "ERROR: Terragrunt did not produce a saved plan for $layer." >&2; exit 1; }
  chmod 600 "$plan_file"
done

echo
echo "All saved plans created. No apply was performed."
echo "Plan directory: $PLAN_DIR"
echo "Review each plan before approval; plan files may contain sensitive values."
