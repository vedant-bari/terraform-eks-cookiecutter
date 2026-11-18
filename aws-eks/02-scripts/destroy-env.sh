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
The bootstrap layer (state bucket and deploy role) is always excluded.
USAGE
}
[[ $# -ge 2 ]] || { usage >&2; exit 2; }
CLIENT=$1; ENV=$2; shift 2
PLAN_DIR=""; DESTROY=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --plan-dir)
      [[ $# -ge 2 ]] || { echo "--plan-dir requires a value" >&2; exit 2; }
      PLAN_DIR=$2; shift 2 ;;
    --destroy) DESTROY=true; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
done

# shellcheck source=lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh"
load_env_config

cd "$REPO_ROOT"
BRANCH="$(git branch --show-current)"
COMMIT="$(git rev-parse HEAD)"
require_clean_tree
assert_aws_account

# Reverse dependency order.
REVERSED=()
for (( i=${#ALL_LAYERS[@]}-1; i>=0; i-- )); do REVERSED+=("${ALL_LAYERS[$i]}"); done

if [[ "$DESTROY" == false ]]; then
  readarray -t LAYERS < <(existing_layers "${REVERSED[@]}")
  [[ ${#LAYERS[@]} -gt 0 ]] || { echo "No deployable live layers exist under $LIVE_DIR" >&2; exit 1; }
  if [[ -z "$PLAN_DIR" ]]; then
    PLAN_DIR="$(mktemp -d "${TMPDIR:-/tmp}/eks-destroy-${CLIENT}-${ENV}.XXXXXX")"
  else
    mkdir -p "$PLAN_DIR"; PLAN_DIR="$(cd "$PLAN_DIR" && pwd)"
    [[ -z "$(find "$PLAN_DIR" -mindepth 1 -maxdepth 1 -print -quit)" ]] || { echo "Plan directory must be empty" >&2; exit 1; }
  fi
  chmod 700 "$PLAN_DIR"
  {
    printf 'mode=destroy\nclient=%s\nenvironment=%s\naccount=%s\nbranch=%s\ncommit=%s\n' \
      "$CLIENT" "$ENV" "$ACCOUNT_ID" "$BRANCH" "$COMMIT"
    printf 'layers=%s\n' "${LAYERS[*]}"
  } > "${PLAN_DIR}/manifest"
  chmod 600 "${PLAN_DIR}/manifest"
  for layer in "${LAYERS[@]}"; do
    layer_dir="${LIVE_DIR}/${layer}"
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
manifest_value() { sed -n "s/^$1=//p" "$MANIFEST"; }
[[ "$(manifest_value mode)" == destroy ]] || { echo "Manifest is not a destroy plan" >&2; exit 1; }
[[ "$(manifest_value client)" == "$CLIENT" && "$(manifest_value environment)" == "$ENV" && "$(manifest_value account)" == "$ACCOUNT_ID" ]] || { echo "Manifest client/environment/account mismatch" >&2; exit 1; }
[[ "$(manifest_value branch)" == "$BRANCH" && "$(manifest_value commit)" == "$COMMIT" ]] || { echo "Branch/commit differs from plan source" >&2; exit 1; }
readarray -t LAYERS < <(manifest_value layers | tr ' ' '\n' | sed '/^$/d')
[[ ${#LAYERS[@]} -gt 0 ]] || { echo "No layer list in destroy manifest" >&2; exit 1; }
PREVIOUS_INDEX=${#ALL_LAYERS[@]}
for layer in "${LAYERS[@]}"; do
  CURRENT_INDEX="$(layer_index "$layer")" || { echo "Unexpected layer in destroy manifest: $layer" >&2; exit 1; }
  (( CURRENT_INDEX < PREVIOUS_INDEX )) || { echo "Destroy manifest layers are duplicated or not in reverse dependency order." >&2; exit 1; }
  PREVIOUS_INDEX=$CURRENT_INDEX
  plan_file="${PLAN_DIR}/${layer}.tfplan"
  [[ -s "$plan_file" ]] || { echo "Missing destroy plan for $layer" >&2; exit 1; }
  expected_hash="$(manifest_value "sha256.${layer}")"
  actual_hash="$(sha256sum "$plan_file" | cut -d ' ' -f1)"
  [[ -n "$expected_hash" && "$expected_hash" == "$actual_hash" ]] || { echo "Destroy plan checksum mismatch for $layer" >&2; exit 1; }
done
GUARD_INDEX="$(layer_index 05-cluster-addons)"
GUARD_DONE=false
for layer in "${LAYERS[@]}"; do
  plan_file="${PLAN_DIR}/${layer}.tfplan"; layer_dir="${LIVE_DIR}/${layer}"
  # Before the controllers or the cluster go, nothing may still own an ALB or volume.
  if [[ "$GUARD_DONE" == false ]] && (( $(layer_index "$layer") <= GUARD_INDEX )); then
    assert_cluster_has_no_aws_backed_objects
    GUARD_DONE=true
  fi
  echo "==> Saved destroy plan for $layer:"
  terragrunt --working-dir "$layer_dir" run -- show -no-color "$plan_file"
  read -r -p "DESTROY resources in $layer using this exact plan? Type 'destroy' to continue: " answer
  [[ "$answer" == destroy ]] || { echo "Destruction stopped at $layer" >&2; exit 1; }
  terragrunt --working-dir "$layer_dir" run -- apply "$plan_file"
done
echo "Destroy plans applied. The bootstrap layer (state bucket, deploy role) was not included."
