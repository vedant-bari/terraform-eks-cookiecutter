#!/usr/bin/env bash
# Destroy is plan-only by default. --layer allows a single component plan.
set -Eeuo pipefail
usage() {
  cat <<'USAGE'
Usage:
  bash destroy-env.sh <client> <environment> [--layer <live-layer>] [--plan-dir <empty-directory>]
  bash destroy-env.sh <client> <environment> --destroy [--layer <live-layer>] --plan-dir <existing-plan-directory>

Default: create saved destroy plans only.
Apply mode: requires --destroy and typed confirmation for every layer.
The S3 backend bucket and bootstrap foundation are never included.
USAGE
}
[[ $# -ge 2 ]] || { usage >&2; exit 2; }
CLIENT=$1; ENV=$2; shift 2
PLAN_DIR=""; DESTROY=false; SELECTED_LAYER=""
while (($#)); do
  case "$1" in
    --plan-dir) [[ $# -ge 2 ]] || { echo "--plan-dir requires a path" >&2; exit 2; }; PLAN_DIR=$2; shift 2 ;;
    --layer) [[ $# -ge 2 ]] || { echo "--layer requires a name" >&2; exit 2; }; SELECTED_LAYER=$2; shift 2 ;;
    --destroy) DESTROY=true; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
done
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
AWS_DIR="${REPO_ROOT}/aws-eks"
LIVE_DIR="${AWS_DIR}/04-live/clients/${CLIENT}/${ENV}"
CONFIG_FILE="${AWS_DIR}/01-config/clients/${CLIENT}/${ENV}/infra/${ENV}.yaml"
[[ -d "$LIVE_DIR" && -f "$CONFIG_FILE" ]] || { echo "Live environment/config not found" >&2; exit 1; }
cd "$REPO_ROOT"
BRANCH="$(git branch --show-current)"; COMMIT="$(git rev-parse HEAD)"
[[ -z "$(git status --porcelain)" ]] || { echo "Refusing to run with a dirty working tree" >&2; exit 1; }
readarray -t CFG < <(python3 - "$CONFIG_FILE" <<'PY'
import sys, yaml
with open(sys.argv[1], encoding="utf-8") as f:
    cfg = yaml.safe_load(f) or {}
print((cfg.get("aws") or {}).get("region", ""))
print((cfg.get("bootstrap") or {}).get("state_bucket_name", ""))
PY
)
AWS_REGION="${CFG[0]:-}"; STATE_BUCKET="${CFG[1]:-}"
[[ -n "$AWS_REGION" && -n "$STATE_BUCKET" ]] || { echo "AWS region or backend bucket missing" >&2; exit 1; }
ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
LAYERS=(08-applications 07-logging 06-monitoring 05-efs-csi 04-ebs-csi 03-eks 02-bastion 01-network)
if [[ -n "$SELECTED_LAYER" ]]; then
  case "$SELECTED_LAYER" in
    01-network|02-bastion|03-eks|04-ebs-csi|05-efs-csi|06-monitoring|07-logging|08-applications) LAYERS=("$SELECTED_LAYER") ;;
    *) echo "Unknown layer: $SELECTED_LAYER" >&2; exit 2 ;;
  esac
fi

if [[ "$DESTROY" == false ]]; then
  aws s3api head-bucket --bucket "$STATE_BUCKET" --region "$AWS_REGION" >/dev/null
  if [[ -z "$PLAN_DIR" ]]; then PLAN_DIR="$(mktemp -d "${TMPDIR:-/tmp}/aws-eks-destroy-${CLIENT}-${ENV}.XXXXXX")"
  else
    mkdir -p "$PLAN_DIR"; PLAN_DIR="$(cd "$PLAN_DIR" && pwd)"
    [[ -z "$(find "$PLAN_DIR" -mindepth 1 -maxdepth 1 -print -quit)" ]] || { echo "Plan directory must be empty" >&2; exit 1; }
  fi
  chmod 700 "$PLAN_DIR"
  {
    printf 'mode=destroy\nclient=%s\nenvironment=%s\nbranch=%s\ncommit=%s\naccount_id=%s\nregion=%s\n' "$CLIENT" "$ENV" "$BRANCH" "$COMMIT" "$ACCOUNT_ID" "$AWS_REGION"
    printf 'layers=%s\n' "${LAYERS[*]}"
  } > "${PLAN_DIR}/manifest"
  chmod 600 "${PLAN_DIR}/manifest"
  for layer in "${LAYERS[@]}"; do
    layer_dir="${LIVE_DIR}/${layer}"
    [[ -f "${layer_dir}/terragrunt.hcl" ]] || { echo "Missing live unit: $layer_dir" >&2; exit 1; }
    plan_file="${PLAN_DIR}/${layer}.tfplan"
    echo "==> Creating destroy plan for $layer"
    terragrunt --working-dir "$layer_dir" run -- plan -destroy -input=false -out="$plan_file"
    [[ -s "$plan_file" ]] || { echo "Missing destroy plan: $plan_file" >&2; exit 1; }
    chmod 600 "$plan_file"
    printf 'sha256.%s=%s\n' "$layer" "$(sha256sum "$plan_file" | cut -d ' ' -f1)" >> "${PLAN_DIR}/manifest"
  done
  echo "Destroy plans saved at $PLAN_DIR. No resources were destroyed."
  exit 0
fi

[[ -n "$PLAN_DIR" && -d "$PLAN_DIR" ]] || { echo "--destroy requires an existing --plan-dir" >&2; exit 2; }
PLAN_DIR="$(cd "$PLAN_DIR" && pwd)"; MANIFEST="${PLAN_DIR}/manifest"
[[ -f "$MANIFEST" ]] || { echo "Missing destroy manifest" >&2; exit 1; }
value() { sed -n "s/^$1=//p" "$MANIFEST"; }
[[ "$(value mode)" == destroy && "$(value client)" == "$CLIENT" && "$(value environment)" == "$ENV" ]] || { echo "Destroy manifest mismatch" >&2; exit 1; }
[[ "$(value branch)" == "$BRANCH" && "$(value commit)" == "$COMMIT" ]] || { echo "Branch/commit differs from saved destroy plans" >&2; exit 1; }
[[ "$(value account_id)" == "$ACCOUNT_ID" ]] || { echo "AWS account differs from destroy-plan account" >&2; exit 1; }
readarray -t LAYERS < <(value layers | tr ' ' '\n' | sed '/^$/d')
[[ ${#LAYERS[@]} -gt 0 ]] || { echo "No layers in destroy manifest" >&2; exit 1; }
if [[ -n "$SELECTED_LAYER" ]]; then
  [[ ${#LAYERS[@]} -eq 1 && "${LAYERS[0]}" == "$SELECTED_LAYER" ]] || { echo "Selected layer does not match the saved destroy manifest" >&2; exit 1; }
fi
EXPECTED=(08-applications 07-logging 06-monitoring 05-efs-csi 04-ebs-csi 03-eks 02-bastion 01-network)
PREVIOUS=-1
for layer in "${LAYERS[@]}"; do
  INDEX=-1
  for i in "${!EXPECTED[@]}"; do [[ "${EXPECTED[$i]}" == "$layer" ]] && INDEX=$i; done
  (( INDEX >= 0 && INDEX > PREVIOUS )) || { echo "Destroy layers are invalid, duplicated, or not in reverse dependency order" >&2; exit 1; }
  PREVIOUS=$INDEX
  plan_file="${PLAN_DIR}/${layer}.tfplan"
  [[ -s "$plan_file" ]] || { echo "Missing destroy plan for $layer" >&2; exit 1; }
  expected_hash="$(sed -n "s/^sha256.${layer}=//p" "$MANIFEST")"
  actual_hash="$(sha256sum "$plan_file" | cut -d ' ' -f1)"
  [[ -n "$expected_hash" && "$expected_hash" == "$actual_hash" ]] || { echo "Destroy plan checksum mismatch: $layer" >&2; exit 1; }
done
for layer in "${LAYERS[@]}"; do
  layer_dir="${LIVE_DIR}/${layer}"; plan_file="${PLAN_DIR}/${layer}.tfplan"
  echo "==> Saved destroy plan for $layer"
  terragrunt --working-dir "$layer_dir" run -- show -no-color "$plan_file"
  read -r -p "DESTROY resources in $layer? Type 'destroy': " answer
  [[ "$answer" == destroy ]] || { echo "Destruction stopped at $layer" >&2; exit 1; }
  terragrunt --working-dir "$layer_dir" run -- apply "$plan_file"
done
echo "Selected destroy plans applied. S3 backend bucket was not included."
