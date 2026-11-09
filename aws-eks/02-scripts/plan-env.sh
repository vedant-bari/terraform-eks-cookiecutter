#!/usr/bin/env bash
# Create private, reviewed Terraform plans. Never applies infrastructure.
set -Eeuo pipefail
umask 077
usage() {
  cat <<'USAGE'
Usage: bash plan-env.sh <client> <environment> [--layer <live-layer>] [--plan-dir <empty-directory>]
Creates saved plans only. Bootstrap/state bucket is a pre-existing prerequisite.
USAGE
}
[[ $# -ge 2 ]] || { usage >&2; exit 2; }
CLIENT=$1; ENV=$2; shift 2
PLAN_DIR=""; SELECTED_LAYER=""
while (($#)); do
  case "$1" in
    --plan-dir) [[ $# -ge 2 ]] || { echo "--plan-dir requires a path" >&2; exit 2; }; PLAN_DIR=$2; shift 2 ;;
    --layer) [[ $# -ge 2 ]] || { echo "--layer requires a name" >&2; exit 2; }; SELECTED_LAYER=$2; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
done
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
AWS_DIR="${REPO_ROOT}/aws-eks"
LIVE_DIR="${AWS_DIR}/04-live/clients/${CLIENT}/${ENV}"
CONFIG_FILE="${AWS_DIR}/01-config/clients/${CLIENT}/${ENV}/infra/${ENV}.yaml"
[[ -f "$CONFIG_FILE" && -d "$LIVE_DIR" ]] || { echo "Missing config or live environment for ${CLIENT}/${ENV}" >&2; exit 1; }
cd "$REPO_ROOT"
BRANCH="$(git branch --show-current)"; COMMIT="$(git rev-parse HEAD)"
[[ -n "$BRANCH" && -n "$COMMIT" ]] || { echo "Unable to identify Git branch/commit" >&2; exit 1; }
[[ -z "$(git status --porcelain)" ]] || { echo "Refusing to plan from a dirty working tree." >&2; exit 1; }

readarray -t CFG < <(python3 - "$CONFIG_FILE" <<'PY'
import sys, yaml
with open(sys.argv[1], encoding="utf-8") as f:
    cfg = yaml.safe_load(f) or {}
print((cfg.get("aws") or {}).get("region", ""))
print((cfg.get("bootstrap") or {}).get("state_bucket_name", ""))
PY
)
AWS_REGION="${CFG[0]:-}"; STATE_BUCKET="${CFG[1]:-}"
[[ -n "$AWS_REGION" && -n "$STATE_BUCKET" ]] || { echo "aws.region or bootstrap.state_bucket_name missing" >&2; exit 1; }
command -v aws >/dev/null || { echo "AWS CLI is required" >&2; exit 1; }
ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
aws s3api head-bucket --bucket "$STATE_BUCKET" --region "$AWS_REGION" >/dev/null

LAYERS=(01-network 02-bastion 03-eks 04-ebs-csi 05-efs-csi 06-monitoring 07-logging 08-applications)
if [[ -n "$SELECTED_LAYER" ]]; then
  case "$SELECTED_LAYER" in
    01-network|02-bastion|03-eks|04-ebs-csi|05-efs-csi|06-monitoring|07-logging|08-applications) LAYERS=("$SELECTED_LAYER") ;;
    *) echo "Unknown layer: $SELECTED_LAYER" >&2; exit 2 ;;
  esac
fi
if [[ -z "$PLAN_DIR" ]]; then
  PLAN_DIR="$(mktemp -d "${TMPDIR:-/tmp}/aws-eks-plan-${CLIENT}-${ENV}.XXXXXX")"
else
  mkdir -p "$PLAN_DIR"; PLAN_DIR="$(cd "$PLAN_DIR" && pwd)"
  [[ -z "$(find "$PLAN_DIR" -mindepth 1 -maxdepth 1 -print -quit)" ]] || { echo "Plan directory must be empty: $PLAN_DIR" >&2; exit 1; }
fi
chmod 700 "$PLAN_DIR"
{
  printf 'mode=plan\nclient=%s\nenvironment=%s\nbranch=%s\ncommit=%s\naccount_id=%s\nregion=%s\n' "$CLIENT" "$ENV" "$BRANCH" "$COMMIT" "$ACCOUNT_ID" "$AWS_REGION"
  printf 'layers=%s\n' "${LAYERS[*]}"
} > "${PLAN_DIR}/manifest"
chmod 600 "${PLAN_DIR}/manifest"
for layer in "${LAYERS[@]}"; do
  layer_dir="${LIVE_DIR}/${layer}"
  [[ -f "${layer_dir}/terragrunt.hcl" ]] || { echo "Missing live unit: $layer_dir" >&2; exit 1; }
  plan_file="${PLAN_DIR}/${layer}.tfplan"
  echo "==> Planning ${CLIENT}/${ENV}/${layer}"
  terragrunt --working-dir "$layer_dir" run -- plan -input=false -out="$plan_file"
  [[ -s "$plan_file" ]] || { echo "Plan was not created: $plan_file" >&2; exit 1; }
  chmod 600 "$plan_file"
  printf 'sha256.%s=%s\n' "$layer" "$(sha256sum "$plan_file" | cut -d ' ' -f1)" >> "${PLAN_DIR}/manifest"
done
echo "Saved plans: $PLAN_DIR"
echo "Review each plan before applying. No infrastructure was changed."
