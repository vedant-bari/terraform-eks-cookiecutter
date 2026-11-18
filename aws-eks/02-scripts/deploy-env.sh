#!/usr/bin/env bash
# Sequential deploy for fresh (or partially built) environments.
#
# For each existing layer, in dependency order:
#   plan (saved to a private temp file) -> show -> type 'yes' -> apply that exact plan.
# Each downstream layer is planned only after its upstream layers are applied, so
# no plan is ever built from mock_outputs. This fixes the GCP limitation where
# plan-env.sh could not plan a brand-new environment.
#
# For environments that already exist, prefer plan-env.sh + apply-env.sh
# (saved plans, manifest and checksum verification).
set -Eeuo pipefail
umask 077

usage() {
  cat <<'USAGE'
Usage: deploy-env.sh <client> <environment> [--from-layer <live-layer>]
Plans and applies each existing layer in order, prompting before every apply.
--from-layer skips the layers before the given one (for resuming).
USAGE
}
[[ $# -ge 2 ]] || { usage >&2; exit 2; }
CLIENT=$1; ENV=$2; shift 2
FROM_LAYER=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --from-layer)
      [[ $# -ge 2 ]] || { echo "--from-layer requires a value" >&2; exit 2; }
      FROM_LAYER=$2; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
done

# shellcheck source=lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh"
load_env_config

cd "$REPO_ROOT"
require_clean_tree
assert_aws_account
assert_state_bucket

START_INDEX=0
if [[ -n "$FROM_LAYER" ]]; then
  START_INDEX="$(layer_index "$FROM_LAYER")" || { echo "Unknown layer: $FROM_LAYER" >&2; exit 2; }
fi
readarray -t LAYERS < <(existing_layers "${ALL_LAYERS[@]:$START_INDEX}")
[[ ${#LAYERS[@]} -gt 0 ]] || { echo "No deployable live layers to run under $LIVE_DIR" >&2; exit 1; }

WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/eks-deploy-${CLIENT}-${ENV}.XXXXXX")"
trap 'rm -rf "$WORK_DIR"' EXIT

for layer in "${LAYERS[@]}"; do
  layer_dir="${LIVE_DIR}/${layer}"
  plan_file="${WORK_DIR}/${layer}.tfplan"
  echo "==> Planning ${CLIENT}/${ENV}/${layer}"
  terragrunt --working-dir "$layer_dir" run -- plan -input=false -out="$plan_file"
  [[ -s "$plan_file" ]] || { echo "Plan file was not created: $plan_file" >&2; exit 1; }
  terragrunt --working-dir "$layer_dir" run -- show -no-color "$plan_file"
  read -r -p "Apply this plan for $layer? Type 'yes' to continue: " answer
  [[ "$answer" == yes ]] || {
    echo "Stopped before applying $layer. Resume later with: --from-layer $layer" >&2
    exit 1
  }
  terragrunt --working-dir "$layer_dir" run -- apply "$plan_file"
done
echo "All layers applied: ${LAYERS[*]}"
