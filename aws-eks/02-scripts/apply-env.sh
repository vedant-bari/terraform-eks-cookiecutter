#!/usr/bin/env bash
# Apply only previously saved plans (from plan-env.sh) after explicit per-layer confirmation.
set -Eeuo pipefail
usage() { echo "Usage: apply-env.sh <client> <environment> --plan-dir <directory> --approve"; }
[[ $# -ge 2 ]] || { usage >&2; exit 2; }
CLIENT=$1; ENV=$2; shift 2
PLAN_DIR=""; APPROVE=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --plan-dir)
      [[ $# -ge 2 ]] || { echo "--plan-dir requires a value" >&2; exit 2; }
      PLAN_DIR=$2; shift 2 ;;
    --approve) APPROVE=true; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
done
[[ "$APPROVE" == true ]] || { echo "Explicit --approve is required; each layer will still prompt for confirmation." >&2; exit 2; }
[[ -n "$PLAN_DIR" && -d "$PLAN_DIR" ]] || { echo "A valid --plan-dir is required" >&2; exit 2; }
PLAN_DIR="$(cd "$PLAN_DIR" && pwd)"
MANIFEST="${PLAN_DIR}/manifest"
[[ -f "$MANIFEST" ]] || { echo "Plan manifest missing: $MANIFEST" >&2; exit 1; }

# shellcheck source=lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh"
load_env_config

manifest_value() { sed -n "s/^$1=//p" "$MANIFEST"; }
[[ "$(manifest_value mode)" == plan \
  && "$(manifest_value client)" == "$CLIENT" \
  && "$(manifest_value environment)" == "$ENV" \
  && "$(manifest_value account)" == "$ACCOUNT_ID" ]] || {
  echo "Manifest does not match requested client/environment/account or plan type" >&2; exit 1;
}

cd "$REPO_ROOT"
M_BRANCH="$(manifest_value branch)"
M_COMMIT="$(manifest_value commit)"
[[ "$(git branch --show-current)" == "$M_BRANCH" ]] || { echo "Current branch differs from plan branch ($M_BRANCH)" >&2; exit 1; }
[[ "$(git rev-parse HEAD)" == "$M_COMMIT" ]] || { echo "HEAD differs from plan commit ($M_COMMIT); create and review fresh plans." >&2; exit 1; }
require_clean_tree
assert_aws_account

readarray -t LAYERS < <(manifest_value layers | tr ' ' '\n' | sed '/^$/d')
[[ ${#LAYERS[@]} -gt 0 ]] || { echo "No layer list in plan manifest" >&2; exit 1; }
PREVIOUS_INDEX=-1
for layer in "${LAYERS[@]}"; do
  CURRENT_INDEX="$(layer_index "$layer")" || { echo "Unexpected layer in plan manifest: $layer" >&2; exit 1; }
  if (( CURRENT_INDEX <= PREVIOUS_INDEX )); then
    echo "Plan manifest layers are duplicated or out of dependency order." >&2; exit 1
  fi
  PREVIOUS_INDEX=$CURRENT_INDEX
done
for layer in "${LAYERS[@]}"; do
  plan_file="${PLAN_DIR}/${layer}.tfplan"
  layer_dir="${LIVE_DIR}/${layer}"
  [[ -s "$plan_file" && -d "$layer_dir" ]] || { echo "Missing plan or live layer for $layer" >&2; exit 1; }
  expected_hash="$(manifest_value "sha256.${layer}")"
  actual_hash="$(sha256sum "$plan_file" | cut -d ' ' -f1)"
  [[ -n "$expected_hash" && "$expected_hash" == "$actual_hash" ]] || { echo "Saved plan checksum mismatch for $layer" >&2; exit 1; }
done

for layer in "${LAYERS[@]}"; do
  plan_file="${PLAN_DIR}/${layer}.tfplan"
  layer_dir="${LIVE_DIR}/${layer}"
  echo "==> Saved plan for ${CLIENT}/${ENV}/${layer}:"
  terragrunt --working-dir "$layer_dir" run -- show -no-color "$plan_file"
  read -r -p "Apply this exact saved plan for $layer? Type 'yes' to continue: " answer
  [[ "$answer" == yes ]] || { echo "Stopped before applying $layer. Earlier approved layers, if any, remain applied." >&2; exit 1; }
  terragrunt --working-dir "$layer_dir" run -- apply "$plan_file"
done
echo "All saved plans applied successfully."
