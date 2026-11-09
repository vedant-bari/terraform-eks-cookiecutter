#!/usr/bin/env bash
# Applies only reviewed saved plans after explicit per-layer confirmation.
set -Eeuo pipefail
usage() { echo "Usage: bash apply-env.sh <client> <environment> --plan-dir <directory> --approve"; }
[[ $# -ge 2 ]] || { usage >&2; exit 2; }
CLIENT=$1; ENV=$2; shift 2
PLAN_DIR=""; APPROVE=false
while (($#)); do
  case "$1" in
    --plan-dir) [[ $# -ge 2 ]] || { echo "--plan-dir requires a path" >&2; exit 2; }; PLAN_DIR=$2; shift 2 ;;
    --approve) APPROVE=true; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
done
[[ "$APPROVE" == true ]] || { echo "Explicit --approve is required; a typed confirmation is still required per layer." >&2; exit 2; }
[[ -n "$PLAN_DIR" && -d "$PLAN_DIR" ]] || { echo "A valid --plan-dir is required" >&2; exit 2; }
PLAN_DIR="$(cd "$PLAN_DIR" && pwd)"; MANIFEST="${PLAN_DIR}/manifest"
[[ -f "$MANIFEST" ]] || { echo "Missing plan manifest" >&2; exit 1; }
value() { sed -n "s/^$1=//p" "$MANIFEST"; }
[[ "$(value mode)" == plan && "$(value client)" == "$CLIENT" && "$(value environment)" == "$ENV" ]] || { echo "Plan manifest mismatch" >&2; exit 1; }
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
LIVE_DIR="${REPO_ROOT}/aws-eks/04-live/clients/${CLIENT}/${ENV}"
cd "$REPO_ROOT"
[[ "$(git branch --show-current)" == "$(value branch)" ]] || { echo "Current branch differs from plan branch" >&2; exit 1; }
[[ "$(git rev-parse HEAD)" == "$(value commit)" ]] || { echo "HEAD differs from plan commit; create fresh plans" >&2; exit 1; }
[[ -z "$(git status --porcelain)" ]] || { echo "Refusing to apply with a dirty working tree" >&2; exit 1; }
CURRENT_ACCOUNT="$(aws sts get-caller-identity --query Account --output text)"
[[ "$CURRENT_ACCOUNT" == "$(value account_id)" ]] || { echo "AWS account differs from plan account" >&2; exit 1; }

readarray -t LAYERS < <(value layers | tr ' ' '\n' | sed '/^$/d')
[[ ${#LAYERS[@]} -gt 0 ]] || { echo "No layers in manifest" >&2; exit 1; }
PREVIOUS=-1
for layer in "${LAYERS[@]}"; do
  case "$layer" in
    01-network) INDEX=0 ;; 02-bastion) INDEX=1 ;; 03-eks) INDEX=2 ;;
    04-ebs-csi) INDEX=3 ;; 05-efs-csi) INDEX=4 ;; 06-monitoring) INDEX=5 ;;
    07-logging) INDEX=6 ;; 08-applications) INDEX=7 ;;
    *) echo "Unexpected layer: $layer" >&2; exit 1 ;;
  esac
  (( INDEX > PREVIOUS )) || { echo "Plan layers are duplicated or out of dependency order" >&2; exit 1; }
  PREVIOUS=$INDEX
  plan_file="${PLAN_DIR}/${layer}.tfplan"
  [[ -s "$plan_file" ]] || { echo "Missing plan: $plan_file" >&2; exit 1; }
  expected="$(sed -n "s/^sha256.${layer}=//p" "$MANIFEST")"
  actual="$(sha256sum "$plan_file" | cut -d ' ' -f1)"
  [[ -n "$expected" && "$expected" == "$actual" ]] || { echo "Plan checksum mismatch: $layer" >&2; exit 1; }
done

for layer in "${LAYERS[@]}"; do
  layer_dir="${LIVE_DIR}/${layer}"; plan_file="${PLAN_DIR}/${layer}.tfplan"
  echo "==> Saved plan for $layer"
  terragrunt --working-dir "$layer_dir" run -- show -no-color "$plan_file"
  read -r -p "Apply this exact plan for $layer? Type 'yes': " answer
  [[ "$answer" == yes ]] || { echo "Stopped before $layer. Previously applied layers remain applied." >&2; exit 1; }
  terragrunt --working-dir "$layer_dir" run -- apply "$plan_file"
done
echo "All selected saved plans applied successfully."
