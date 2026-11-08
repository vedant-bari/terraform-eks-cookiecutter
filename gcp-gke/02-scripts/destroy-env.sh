#!/usr/bin/env bash
# Safe two-stage teardown: default creates saved destroy plans only.
# Actual destruction requires --destroy, --approve, a matching plan directory,
# and a per-layer typed confirmation. The bootstrap/state bucket is excluded.
set -Eeuo pipefail
umask 077

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
GCP_GKE_DIR="${REPO_ROOT}/gcp-gke"
LAYERS=(07-applications 06-jenkins 04-storage 03-artifact-registry 02-gke 01-network)

usage() {
  echo "Plan (default): bash gcp-gke/02-scripts/destroy-env.sh <client> <environment> [--plan-dir <directory>]"
  echo "Destroy:        bash gcp-gke/02-scripts/destroy-env.sh <client> <environment> --destroy --plan-dir <directory> --approve"
}

[[ $# -ge 2 ]] || { usage; exit 2; }
CLIENT="$1"; ENV="$2"; shift 2
[[ "$CLIENT" =~ ^[a-z0-9][a-z0-9-]*$ && "$ENV" =~ ^[a-z0-9][a-z0-9-]*$ ]] || {
  echo "ERROR: client and environment must be lowercase alphanumeric/hyphen identifiers." >&2; exit 2;
}
PLAN_DIR=""; DO_DESTROY=false; APPROVE=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --plan-dir) [[ $# -ge 2 && -n "$2" ]] || { echo "ERROR: --plan-dir requires a path." >&2; exit 2; }; PLAN_DIR="$2"; shift 2 ;;
    --destroy) DO_DESTROY=true; shift ;;
    --approve) APPROVE=true; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "ERROR: Unknown argument: $1" >&2; usage; exit 2 ;;
  esac
done
command -v terragrunt >/dev/null || { echo "ERROR: terragrunt is not installed." >&2; exit 1; }
cd "$REPO_ROOT"
BRANCH="$(git branch --show-current)"
COMMIT="$(git rev-parse HEAD)"
[[ -n "$BRANCH" && -z "$(git status --porcelain)" ]] || {
  echo "ERROR: Use a named branch and a clean working tree." >&2; exit 1;
}
LIVE_DIR="${GCP_GKE_DIR}/04-live/clients/${CLIENT}/${ENV}"
[[ -d "$LIVE_DIR" ]] || { echo "ERROR: Missing live directory: $LIVE_DIR" >&2; exit 1; }

if [[ "$DO_DESTROY" = false ]]; then
  [[ "$APPROVE" = false ]] || { echo "ERROR: --approve is only valid with --destroy." >&2; exit 2; }
  if [[ -z "$PLAN_DIR" ]]; then
    PLAN_DIR="${TMPDIR:-/tmp}/gke-destroy-plans-${CLIENT}-${ENV}-$(date -u +%Y%m%dT%H%M%SZ)"
  fi
  [[ "$PLAN_DIR" = /* ]] || PLAN_DIR="${REPO_ROOT}/${PLAN_DIR}"
  mkdir -p "$PLAN_DIR"
  PLAN_DIR="$(cd "$PLAN_DIR" && pwd)"
  case "$PLAN_DIR/" in "$REPO_ROOT/"*) echo "ERROR: Plan directory must be outside the repository." >&2; exit 1 ;; esac
  [[ -z "$(find "$PLAN_DIR" -mindepth 1 -maxdepth 1 -print -quit)" ]] || {
    echo "ERROR: Plan directory must be empty: $PLAN_DIR" >&2; exit 1;
  }
  {
    printf 'operation=destroy\nclient=%s\nenvironment=%s\nbranch=%s\ncommit=%s\ncreated_utc=%s\n' \
      "$CLIENT" "$ENV" "$BRANCH" "$COMMIT" "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  } > "${PLAN_DIR}/manifest.txt"
  chmod 600 "${PLAN_DIR}/manifest.txt"
  for layer in "${LAYERS[@]}"; do
    [[ -d "${LIVE_DIR}/${layer}" ]] || { echo "ERROR: Missing live layer: $layer" >&2; exit 1; }
    echo "===== DESTROY PLAN: $CLIENT/$ENV/$layer ====="
    (
      cd "${LIVE_DIR}/${layer}"
      terragrunt init
      terragrunt run -- plan -destroy -out="${PLAN_DIR}/${layer}.tfplan"
    )
    [[ -s "${PLAN_DIR}/${layer}.tfplan" ]] || { echo "ERROR: Missing destroy plan for $layer." >&2; exit 1; }
    chmod 600 "${PLAN_DIR}/${layer}.tfplan"
  done
  echo "Destroy plans created only; no resources were destroyed."
  echo "Plan directory: $PLAN_DIR"
  echo "The bootstrap/state bucket is intentionally excluded."
  exit 0
fi

[[ "$APPROVE" = true && -n "$PLAN_DIR" ]] || {
  echo "ERROR: --destroy requires both --plan-dir and explicit --approve." >&2; usage; exit 2;
}
[[ -t 0 ]] || { echo "ERROR: Interactive terminal required for per-layer destroy confirmation." >&2; exit 1; }
[[ -d "$PLAN_DIR" ]] || { echo "ERROR: Plan directory not found." >&2; exit 1; }
PLAN_DIR="$(cd "$PLAN_DIR" && pwd)"
case "$PLAN_DIR/" in "$REPO_ROOT/"*) echo "ERROR: Plan directory must be outside the repository." >&2; exit 1 ;; esac
MANIFEST="${PLAN_DIR}/manifest.txt"
[[ -f "$MANIFEST" ]] || { echo "ERROR: Missing destroy-plan manifest." >&2; exit 1; }
grep -Fxq "operation=destroy" "$MANIFEST" || { echo "ERROR: Manifest is not a destroy-plan manifest." >&2; exit 1; }
grep -Fxq "client=$CLIENT" "$MANIFEST" && grep -Fxq "environment=$ENV" "$MANIFEST" || {
  echo "ERROR: Client/environment do not match the destroy-plan manifest." >&2; exit 1;
}
grep -Fxq "branch=$BRANCH" "$MANIFEST" && grep -Fxq "commit=$COMMIT" "$MANIFEST" || {
  echo "ERROR: Branch/commit differ from destroy-plan manifest. Regenerate and re-review." >&2; exit 1;
}
for layer in "${LAYERS[@]}"; do
  [[ -s "${PLAN_DIR}/${layer}.tfplan" ]] || { echo "ERROR: Missing saved destroy plan for $layer." >&2; exit 1; }
done

echo "WARNING: This will destroy resources using only the saved destroy plans in $PLAN_DIR."
for layer in "${LAYERS[@]}"; do
  echo
  read -r -p "Type DESTROY $CLIENT/$ENV/$layer to execute this saved destroy plan: " confirmation
  [[ "$confirmation" == "DESTROY $CLIENT/$ENV/$layer" ]] || {
    echo "Stopped before destroying $layer. Already destroyed layers are not recreated." >&2; exit 1;
  }
  (
    cd "${LIVE_DIR}/${layer}"
    terragrunt init
    terragrunt run -- apply "${PLAN_DIR}/${layer}.tfplan"
  )
done
echo "Saved destroy-plan sequence completed for $CLIENT/$ENV."
