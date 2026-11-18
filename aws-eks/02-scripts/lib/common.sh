#!/usr/bin/env bash
# Shared helpers for the aws-eks environment scripts. Source, do not execute.
# Callers must set CLIENT and ENV before calling load_env_config.

AWS_EKS_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${AWS_EKS_LIB_DIR}/../../.." && pwd)"
AWS_EKS_DIR="${REPO_ROOT}/aws-eks"

# Deployable layers in dependency order. 00-bootstrap is intentionally excluded:
# the S3 backend must exist before init, so bootstrap is run by hand (see
# 00-documentation/deployment/BOOTSTRAP.md).
ALL_LAYERS=(
  01-network
  02-eks
  03-ecr
  04-storage
  05-cluster-addons
  06-monitoring
  07-jenkins
  08-applications
)

# Echo the dependency index of a layer, or fail for unknown layers.
layer_index() {
  local i
  for i in "${!ALL_LAYERS[@]}"; do
    [[ "${ALL_LAYERS[$i]}" == "$1" ]] && { echo "$i"; return 0; }
  done
  return 1
}

# Sets LIVE_DIR, CONFIG_FILE, ACCOUNT_ID, REGION, PROFILE, STATE_BUCKET,
# CLUSTER_NAME, DEPLOY_ROLE_ARN and AWS_ARGS.
load_env_config() {
  LIVE_DIR="${AWS_EKS_DIR}/04-live/clients/${CLIENT}/${ENV}"
  CONFIG_FILE="${AWS_EKS_DIR}/01-config/clients/${CLIENT}/${ENV}/infra/${ENV}.yaml"
  [[ -f "$CONFIG_FILE" ]] || { echo "Config not found: $CONFIG_FILE" >&2; return 1; }
  [[ -d "$LIVE_DIR" ]] || { echo "Live directory not found: $LIVE_DIR" >&2; return 1; }

  local cfg
  cfg="$(python3 "${AWS_EKS_LIB_DIR}/read_env_config.py" "$CONFIG_FILE" "$CLIENT" "$ENV")" || return 1
  readarray -t CFG <<<"$cfg"
  ACCOUNT_ID="${CFG[0]}"
  REGION="${CFG[1]}"
  PROFILE="${CFG[2]}"
  STATE_BUCKET="${CFG[3]}"
  CLUSTER_NAME="${CFG[4]}"
  DEPLOY_ROLE_ARN="${CFG[5]:-}"
  AWS_ARGS=(--region "$REGION")
  [[ -n "$PROFILE" ]] && AWS_ARGS+=(--profile "$PROFILE")
  return 0
}

# Fail unless the active AWS credentials belong to the configured account.
assert_aws_account() {
  command -v aws >/dev/null || { echo "aws CLI v2 is required" >&2; return 1; }
  local actual
  actual="$(aws "${AWS_ARGS[@]}" sts get-caller-identity --query Account --output text)" || return 1
  [[ "$actual" == "$ACCOUNT_ID" ]] || {
    echo "Credentials belong to account $actual, but config expects $ACCOUNT_ID. Refusing to continue." >&2
    return 1
  }
}

# Read-only check that the state bucket exists and is reachable.
assert_state_bucket() {
  aws "${AWS_ARGS[@]}" s3api head-bucket --bucket "$STATE_BUCKET" >/dev/null || {
    echo "State bucket $STATE_BUCKET is missing or not accessible. Run 02-scripts/bootstrap/01-create-bootstrap-bucket.sh first." >&2
    return 1
  }
}

require_clean_tree() {
  [[ -z "$(git -C "$REPO_ROOT" status --porcelain)" ]] || {
    echo "Refusing to run from a dirty working tree." >&2
    return 1
  }
}

# Print the subset of ALL_LAYERS (or the reverse) whose live directory exists.
# Missing layers are reported, so a partially built environment can be planned
# phase by phase.
existing_layers() {
  local order=("$@") layer
  for layer in "${order[@]}"; do
    if [[ -d "${LIVE_DIR}/${layer}" ]]; then
      echo "$layer"
    else
      echo "Note: live layer ${layer} does not exist yet; skipping." >&2
    fi
  done
}

# R2 guard. Load balancers (from Ingress / LoadBalancer Services) and EBS/EFS
# volumes (from PVCs) are created by in-cluster controllers and are not in
# Terraform state. Destroying the controllers or the cluster first orphans
# them, and the VPC destroy then hangs on their ENIs. Fail if any remain.
# Passes when the cluster does not exist.
assert_cluster_has_no_aws_backed_objects() {
  if ! aws "${AWS_ARGS[@]}" eks describe-cluster --name "$CLUSTER_NAME" >/dev/null 2>&1; then
    echo "Cluster $CLUSTER_NAME not found; skipping the leftover load balancer/volume check."
    return 0
  fi
  command -v kubectl >/dev/null || { echo "kubectl is required for the pre-destroy check" >&2; return 1; }

  local kubeconfig rc=0 ingresses services pvcs
  kubeconfig="$(mktemp)"
  local role_args=()
  [[ -n "${DEPLOY_ROLE_ARN:-}" ]] && role_args=(--role-arn "$DEPLOY_ROLE_ARN")
  aws "${AWS_ARGS[@]}" eks update-kubeconfig --name "$CLUSTER_NAME" --kubeconfig "$kubeconfig" "${role_args[@]}" >/dev/null || { rm -f "$kubeconfig"; return 1; }

  ingresses="$(kubectl --kubeconfig "$kubeconfig" get ingress -A --no-headers -o custom-columns=NS:.metadata.namespace,NAME:.metadata.name 2>&1)" || rc=1
  services="$(kubectl --kubeconfig "$kubeconfig" get svc -A -o jsonpath='{range .items[?(@.spec.type=="LoadBalancer")]}{.metadata.namespace}{" "}{.metadata.name}{"\n"}{end}' 2>&1)" || rc=1
  pvcs="$(kubectl --kubeconfig "$kubeconfig" get pvc -A --no-headers -o custom-columns=NS:.metadata.namespace,NAME:.metadata.name 2>&1)" || rc=1
  rm -f "$kubeconfig"
  if (( rc != 0 )); then
    echo "Could not list cluster objects for the pre-destroy check:" >&2
    printf '%s\n' "$ingresses" "$services" "$pvcs" >&2
    return 1
  fi

  if [[ -n "$ingresses$services$pvcs" ]]; then
    echo "Refusing to destroy: these objects still own AWS resources outside Terraform state." >&2
    [[ -n "$ingresses" ]] && printf 'Ingresses (ALBs):\n%s\n' "$ingresses" >&2
    [[ -n "$services" ]] && printf 'LoadBalancer Services (NLB/CLB):\n%s\n' "$services" >&2
    [[ -n "$pvcs" ]] && printf 'PVCs (EBS volumes / EFS access points):\n%s\n' "$pvcs" >&2
    echo "Delete them (kubectl delete ingress|svc|pvc -n <ns> <name>), wait for the load balancers and volumes to go, then re-run." >&2
    return 1
  fi
  echo "Pre-destroy check passed: no Ingresses, LoadBalancer Services or PVCs remain."
}
