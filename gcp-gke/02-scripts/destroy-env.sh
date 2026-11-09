#!/usr/bin/env bash
# Destroy is plan-only by default. Applying requires --destroy and saved plans.
set -Eeuo pipefail
usage() {
  cat <<'USAGE'
Usage:
  destroy-env.sh <client> <environment> [--plan-dir <directory>]
  destroy-env.sh <client> <environment> --destroy --plan-dir <existing-plan-directory>

Default: create saved destroy plans only.
Apply mode: requires --destroy and prompts for each saved plan.
The bootstrap/state bucket is always excluded.
USAGE
}
[[ $# -ge 2 ]] || { usage >&2; exit 2; }
CLIENT=$1; ENV=$2; shift 2
PLAN_DIR=""; DESTROY=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --plan-dir)
      [[ $# -ge 2 ]] || { echo "--plan-dir requires a value" >&2; exit 2; }
      PLAN_DIR=$2
      shift 2
      ;;
    --destroy)
      DESTROY=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
LIVE_DIR="${REPO_ROOT}/gcp-gke/04-live/clients/${CLIENT}/${ENV}"
[[ -d "$LIVE_DIR" ]] || { echo "Live directory not found: $LIVE_DIR" >&2; exit 1; }
cd "$REPO_ROOT"
BRANCH="$(git branch --show-current)"
COMMIT="$(git rev-parse HEAD)"
[[ -z "$(git status --porcelain)" ]] || { echo "Refusing to run with a dirty working tree." >&2; exit 1; }
LAYERS=(07-applications 06-jenkins 04-storage 03-artifact-registry 02-gke 01-network)

if [[ "$DESTROY" == false ]]; then
  if [[ -z "$PLAN_DIR" ]]; then
    PLAN_DIR="$(mktemp -d "${TMPDIR:-/tmp}/gke-destroy-${CLIENT}-${ENV}.XXXXXX")"
  else
    mkdir -p "$PLAN_DIR"; PLAN_DIR="$(cd "$PLAN_DIR" && pwd)"
    [[ -z "$(find "$PLAN_DIR" -mindepth 1 -maxdepth 1 -print -quit)" ]] || { echo "Plan directory must be empty" >&2; exit 1; }
  fi
  chmod 700 "$PLAN_DIR"
  {
    printf 'mode=destroy\nclient=%s\nenvironment=%s\nbranch=%s\ncommit=%s\n' "$CLIENT" "$ENV" "$BRANCH" "$COMMIT"
    printf 'layers=%s\n' "${LAYERS[*]}"
  } > "${PLAN_DIR}/manifest"
  chmod 600 "${PLAN_DIR}/manifest"
  for layer in "${LAYERS[@]}"; do
    layer_dir="${LIVE_DIR}/${layer}"
    [[ -d "$layer_dir" ]] || { echo "Required live layer missing: $layer_dir" >&2; exit 1; }
    plan_file="${PLAN_DIR}/${layer}.tfplan"
    echo "==> Creating destroy plan for $layer"
    terragrunt --working-dir "$layer_dir" run -- plan -destroy -input=false -out="$plan_file"
    [[ -s "$plan_file" ]] || { echo "Destroy plan missing: $plan_file" >&2; exit 1; }
    chmod 600 "$plan_file"
    printf 'sha256.%s=%s\n' "$layer" "$(sha256sum "$plan_file" | cut -d ' ' -f1)" >> "${PLAN_DIR}/manifest"
  done
  echo "Destroy plans saved at: $PLAN_DIR"
  echo "Review each plan before using --destroy. No resources were destroyed."
  exit 0
fi

[[ -n "$PLAN_DIR" && -d "$PLAN_DIR" ]] || { echo "--destroy requires --plan-dir pointing to existing reviewed plans" >&2; exit 2; }
PLAN_DIR="$(cd "$PLAN_DIR" && pwd)"
MANIFEST="${PLAN_DIR}/manifest"
[[ -f "$MANIFEST" ]] || { echo "Destroy plan manifest missing" >&2; exit 1; }
[[ "$(sed -n 's/^mode=//p' "$MANIFEST")" == destroy ]] || { echo "Manifest is not a destroy plan" >&2; exit 1; }
[[ "$(sed -n 's/^client=//p' "$MANIFEST")" == "$CLIENT" && "$(sed -n 's/^environment=//p' "$MANIFEST")" == "$ENV" ]] || { echo "Manifest environment mismatch" >&2; exit 1; }
[[ "$(sed -n 's/^branch=//p' "$MANIFEST")" == "$BRANCH" && "$(sed -n 's/^commit=//p' "$MANIFEST")" == "$COMMIT" ]] || { echo "Branch/commit differs from plan source" >&2; exit 1; }
for layer in "${LAYERS[@]}"; do
  plan_file="${PLAN_DIR}/${layer}.tfplan"
  [[ -s "$plan_file" ]] || { echo "Missing destroy plan for $layer" >&2; exit 1; }
  expected_hash="$(sed -n "s/^sha256.${layer}=//p" "$MANIFEST")"
  actual_hash="$(sha256sum "$plan_file" | cut -d ' ' -f1)"
  [[ -n "$expected_hash" && "$expected_hash" == "$actual_hash" ]] || { echo "Destroy plan checksum mismatch for $layer" >&2; exit 1; }
done
for layer in "${LAYERS[@]}"; do
  plan_file="${PLAN_DIR}/${layer}.tfplan"; layer_dir="${LIVE_DIR}/${layer}"
  echo "==> Saved destroy plan for $layer:"
  terragrunt --working-dir "$layer_dir" run -- show -no-color "$plan_file"
  read -r -p "DESTROY resources in $layer using this exact plan? Type 'destroy' to continue: " answer
  [[ "$answer" == destroy ]] || { echo "Destruction stopped at $layer" >&2; exit 1; }
  terragrunt --working-dir "$layer_dir" run -- apply "$plan_file"
done
echo "Destroy plans applied. Bootstrap/state bucket was not included."
