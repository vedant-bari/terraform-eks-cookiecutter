#!/usr/bin/env bash
# Create reviewed, saved Terraform plans. This script never applies changes.
set -Eeuo pipefail
umask 077

usage() {
  cat <<'USAGE'
Usage: plan-env.sh <client> <environment> [--layer <live-layer>] [--plan-dir <directory>]
Creates one saved plan per active live layer. Does not scaffold, import, or apply.
USAGE
}
[[ $# -ge 2 ]] || { usage >&2; exit 2; }
CLIENT=$1; ENV=$2; shift 2
PLAN_DIR=""
SELECTED_LAYER=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --plan-dir)
      [[ $# -ge 2 ]] || { echo "--plan-dir requires a value" >&2; exit 2; }
      PLAN_DIR=$2; shift 2 ;;
    --layer)
      [[ $# -ge 2 ]] || { echo "--layer requires a value" >&2; exit 2; }
      SELECTED_LAYER=$2; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
GCP_GKE_DIR="${REPO_ROOT}/gcp-gke"
LIVE_DIR="${GCP_GKE_DIR}/04-live/clients/${CLIENT}/${ENV}"
CONFIG_FILE="${GCP_GKE_DIR}/01-config/clients/${CLIENT}/${ENV}/infra/${ENV}.yaml"
[[ -f "$CONFIG_FILE" ]] || { echo "Config not found: $CONFIG_FILE" >&2; exit 1; }
[[ -d "$LIVE_DIR" ]] || { echo "Live directory not found: $LIVE_DIR" >&2; exit 1; }

cd "$REPO_ROOT"
BRANCH="$(git branch --show-current)"
COMMIT="$(git rev-parse HEAD)"
[[ -n "$BRANCH" && -n "$COMMIT" ]] || { echo "Unable to identify Git branch/commit" >&2; exit 1; }
[[ -z "$(git status --porcelain)" ]] || { echo "Refusing to plan from a dirty working tree." >&2; exit 1; }

readarray -t CFG < <(python3 - "$CONFIG_FILE" <<'PY'
import sys, yaml
with open(sys.argv[1], encoding="utf-8") as f:
    cfg = yaml.safe_load(f) or {}
print((cfg.get("gcp") or {}).get("project_id", ""))
print((cfg.get("bootstrap") or {}).get("state_bucket_name", ""))
PY
)
PROJECT_ID="${CFG[0]:-}"
STATE_BUCKET="${CFG[1]:-}"
[[ -n "$PROJECT_ID" && -n "$STATE_BUCKET" ]] || { echo "project_id or bootstrap.state_bucket_name missing in config" >&2; exit 1; }
command -v gcloud >/dev/null || { echo "gcloud CLI is required for the read-only backend bucket check" >&2; exit 1; }
gcloud storage buckets describe "gs://${STATE_BUCKET}" --project="$PROJECT_ID" >/dev/null

if [[ -z "$PLAN_DIR" ]]; then
  PLAN_DIR="$(mktemp -d "${TMPDIR:-/tmp}/gke-plan-${CLIENT}-${ENV}.XXXXXX")"
else
  mkdir -p "$PLAN_DIR"
  PLAN_DIR="$(cd "$PLAN_DIR" && pwd)"
  [[ -z "$(find "$PLAN_DIR" -mindepth 1 -maxdepth 1 -print -quit)" ]] || {
    echo "Plan directory must be empty: $PLAN_DIR" >&2; exit 1;
  }
fi
chmod 700 "$PLAN_DIR"

# Bootstrap is intentionally excluded: the GCS backend must exist before init.
LAYERS=(01-network 02-gke 03-artifact-registry 04-storage 05-monitoring 06-jenkins 07-applications)
if [[ -n "$SELECTED_LAYER" ]]; then
  case "$SELECTED_LAYER" in
    01-network|02-gke|03-artifact-registry|04-storage|05-monitoring|06-jenkins|07-applications) LAYERS=("$SELECTED_LAYER") ;;
    *) echo "Unknown or non-deployable layer: $SELECTED_LAYER" >&2; exit 2 ;;
  esac
fi
MANIFEST="${PLAN_DIR}/manifest"
{
  printf 'mode=plan\nclient=%s\nenvironment=%s\nbranch=%s\ncommit=%s\n' "$CLIENT" "$ENV" "$BRANCH" "$COMMIT"
  printf 'layers=%s\n' "${LAYERS[*]}"
} > "$MANIFEST"
chmod 600 "$MANIFEST"

for layer in "${LAYERS[@]}"; do
  layer_dir="${LIVE_DIR}/${layer}"
  [[ -d "$layer_dir" ]] || { echo "Required live layer missing: $layer_dir" >&2; exit 1; }
  plan_file="${PLAN_DIR}/${layer}.tfplan"
  echo "==> Planning ${CLIENT}/${ENV}/${layer}"
  terragrunt --working-dir "$layer_dir" run -- plan -input=false -out="$plan_file"
  [[ -s "$plan_file" ]] || { echo "Plan file was not created: $plan_file" >&2; exit 1; }
  chmod 600 "$plan_file"
  printf 'sha256.%s=%s\n' "$layer" "$(sha256sum "$plan_file" | cut -d ' ' -f1)" >> "$MANIFEST"
done

echo
echo "Saved plans created. Review each with:"
for layer in "${LAYERS[@]}"; do
  printf '  terragrunt --working-dir "%s/%s" run -- show -no-color "%s/%s.tfplan"\n' "$LIVE_DIR" "$layer" "$PLAN_DIR" "$layer"
done
echo
echo "Plan directory: $PLAN_DIR"
echo "No apply, import, scaffolding, or state migration was performed."
