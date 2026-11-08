#!/usr/bin/env bash
# Apply only previously saved and reviewed plan files. Never regenerates plans.
set -Eeuo pipefail
umask 077

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
GCP_GKE_DIR="${REPO_ROOT}/gcp-gke"
LAYERS=(01-network 02-gke 03-artifact-registry 04-storage 06-jenkins 07-applications)

usage() {
  echo "Usage: bash gcp-gke/02-scripts/apply-env.sh <client> <environment> --plan-dir <directory> --approve"
}

[[ $# -ge 2 ]] || { usage; exit 2; }
CLIENT="$1"; ENV="$2"; shift 2
[[ "$CLIENT" =~ ^[a-z0-9][a-z0-9-]*$ && "$ENV" =~ ^[a-z0-9][a-z0-9-]*$ ]] || {
  echo "ERROR: client and environment must be lowercase alphanumeric/hyphen identifiers." >&2; exit 2;
}
PLAN_DIR=""; APPROVE=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --plan-dir) [[ $# -ge 2 && -n "$2" ]] || { echo "ERROR: --plan-dir requires a path." >&2; exit 2; }; PLAN_DIR="$2"; shift 2 ;;
    --approve) APPROVE=true; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "ERROR: Unknown argument: $1" >&2; usage; exit 2 ;;
  esac
done
[[ -n "$PLAN_DIR" && "$APPROVE" = true ]] || { echo "ERROR: --plan-dir and explicit --approve are required." >&2; usage; exit 2; }
command -v terragrunt >/dev/null || { echo "ERROR: terragrunt is not installed." >&2; exit 1; }

cd "$REPO_ROOT"
BRANCH="$(git branch --show-current)"
COMMIT="$(git rev-parse HEAD)"
[[ -z "$(git status --porcelain)" ]] || { echo "ERROR: Working tree must be clean before applying saved plans." >&2; exit 1; }

[[ -d "$PLAN_DIR" ]] || { echo "ERROR: Plan directory not found: $PLAN_DIR" >&2; exit 1; }
PLAN_DIR="$(cd "$PLAN_DIR" && pwd)"
case "$PLAN_DIR/" in "$REPO_ROOT/"*) echo "ERROR: Plan directory must be outside the repository." >&2; exit 1 ;; esac
MANIFEST="${PLAN_DIR}/manifest.txt"
[[ -f "$MANIFEST" ]] || { echo "ERROR: Missing plan manifest." >&2; exit 1; }
grep -Fxq "operation=plan" "$MANIFEST" || { echo "ERROR: Manifest is not a deployment-plan manifest." >&2; exit 1; }
grep -Fxq "client=$CLIENT" "$MANIFEST" || { echo "ERROR: Client does not match plan manifest." >&2; exit 1; }
grep -Fxq "environment=$ENV" "$MANIFEST" || { echo "ERROR: Environment does not match plan manifest." >&2; exit 1; }
grep -Fxq "branch=$BRANCH" "$MANIFEST" || { echo "ERROR: Current branch differs from plan branch." >&2; exit 1; }
grep -Fxq "commit=$COMMIT" "$MANIFEST" || { echo "ERROR: HEAD differs from plan commit; regenerate and re-review plans." >&2; exit 1; }

LIVE_DIR="${GCP_GKE_DIR}/04-live/clients/${CLIENT}/${ENV}"
for layer in "${LAYERS[@]}"; do
  [[ -d "${LIVE_DIR}/${layer}" ]] || { echo "ERROR: Missing live layer: $layer" >&2; exit 1; }
  [[ -s "${PLAN_DIR}/${layer}.tfplan" ]] || { echo "ERROR: Missing saved plan for $layer." >&2; exit 1; }
done

[[ -t 0 ]] || { echo "ERROR: Interactive terminal required for per-layer confirmation." >&2; exit 1; }
echo "Applying the exact saved plans from: $PLAN_DIR"
echo "Branch: $BRANCH"
echo "Commit: $COMMIT"
echo "No new plans will be generated."
for layer in "${LAYERS[@]}"; do
  echo
  read -r -p "Type APPLY $CLIENT/$ENV/$layer to apply this saved plan: " confirmation
  [[ "$confirmation" == "APPLY $CLIENT/$ENV/$layer" ]] || {
    echo "Stopped before applying $layer. Previously applied layers, if any, are not rolled back." >&2; exit 1;
  }
  (
    cd "${LIVE_DIR}/${layer}"
    terragrunt init
    terragrunt run -- apply "${PLAN_DIR}/${layer}.tfplan"
  )
done
echo "Saved-plan apply sequence completed for $CLIENT/$ENV."
