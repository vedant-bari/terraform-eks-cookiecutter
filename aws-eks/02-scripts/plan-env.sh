#!/usr/bin/env bash
# Create reviewed, saved Terraform plans. This script never applies changes.
#
# Saved plans are only meaningful for an environment whose dependency layers are
# already applied. For a fresh environment use deploy-env.sh, which plans and
# applies one layer at a time so each plan sees real upstream outputs.
set -Eeuo pipefail
umask 077

usage() {
  cat <<'USAGE'
Usage: plan-env.sh <client> <environment> [--layer <live-layer>] [--plan-dir <directory>]
Creates one saved plan per existing live layer. Does not scaffold, import, or apply.
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

# shellcheck source=lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh"
load_env_config

cd "$REPO_ROOT"
BRANCH="$(git branch --show-current)"
COMMIT="$(git rev-parse HEAD)"
[[ -n "$BRANCH" && -n "$COMMIT" ]] || { echo "Unable to identify Git branch/commit" >&2; exit 1; }
require_clean_tree
assert_aws_account
assert_state_bucket

if [[ -n "$SELECTED_LAYER" ]]; then
  layer_index "$SELECTED_LAYER" >/dev/null || { echo "Unknown or non-deployable layer: $SELECTED_LAYER" >&2; exit 2; }
  [[ -d "${LIVE_DIR}/${SELECTED_LAYER}" ]] || { echo "Live layer missing: ${LIVE_DIR}/${SELECTED_LAYER}" >&2; exit 1; }
  LAYERS=("$SELECTED_LAYER")
else
  readarray -t LAYERS < <(existing_layers "${ALL_LAYERS[@]}")
fi
[[ ${#LAYERS[@]} -gt 0 ]] || { echo "No deployable live layers exist under $LIVE_DIR" >&2; exit 1; }

if [[ -z "$PLAN_DIR" ]]; then
  PLAN_DIR="$(mktemp -d "${TMPDIR:-/tmp}/eks-plan-${CLIENT}-${ENV}.XXXXXX")"
else
  mkdir -p "$PLAN_DIR"
  PLAN_DIR="$(cd "$PLAN_DIR" && pwd)"
  [[ -z "$(find "$PLAN_DIR" -mindepth 1 -maxdepth 1 -print -quit)" ]] || {
    echo "Plan directory must be empty: $PLAN_DIR" >&2; exit 1;
  }
fi
chmod 700 "$PLAN_DIR"

MANIFEST="${PLAN_DIR}/manifest"
{
  printf 'mode=plan\nclient=%s\nenvironment=%s\naccount=%s\nbranch=%s\ncommit=%s\n' \
    "$CLIENT" "$ENV" "$ACCOUNT_ID" "$BRANCH" "$COMMIT"
  printf 'layers=%s\n' "${LAYERS[*]}"
} > "$MANIFEST"
chmod 600 "$MANIFEST"

for layer in "${LAYERS[@]}"; do
  layer_dir="${LIVE_DIR}/${layer}"
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
