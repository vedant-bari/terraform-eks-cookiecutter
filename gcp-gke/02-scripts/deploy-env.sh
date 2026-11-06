#!/usr/bin/env bash
# ==============================================================================
# GKE Platform Blueprint - Automated Infrastructure Deployment Orchestrator
# ==============================================================================
# Usage:
#   ./gcp-gke/02-scripts/deploy-env.sh <client-name> <environment> [options]
#
# Options:
#   --plan-only       Run Terragrunt plan for each layer without provisioning
#   --dry-run         Validate configuration, scaffolding, and DAG without cloud calls
#   --auto-approve    Apply changes without interactive confirmation prompts
#   --skip-scaffold   Skip re-running Python scaffolding generators
#
# Example:
#   ./gcp-gke/02-scripts/deploy-env.sh amex prod --plan-only
# ==============================================================================

set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
GCP_GKE_DIR="${REPO_ROOT}/gcp-gke"

cd "${REPO_ROOT}"

# --- ANSI Colors ---
GREEN="\033[0;32m"
RED="\033[0;31m"
YELLOW="\033[1;33m"
CYAN="\033[0;36m"
BOLD="\033[1m"
NC="\033[0m"

# --- Argument Parsing ---
if [ "$#" -lt 2 ]; then
  echo -e "${RED}❌ Error: Missing required arguments.${NC}"
  echo -e "Usage: $0 <client-name> <environment> [--plan-only] [--dry-run] [--auto-approve] [--skip-scaffold]"
  echo -e "Example: $0 amex prod --plan-only"
  exit 1
fi

CLIENT="$1"
ENV="$2"
shift 2

PLAN_ONLY=false
DRY_RUN=false
AUTO_APPROVE=""
SKIP_SCAFFOLD=false
UPGRADE=""

while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --plan-only) PLAN_ONLY=true ;;
    --dry-run) DRY_RUN=true; PLAN_ONLY=true ;;
    --auto-approve) AUTO_APPROVE="-auto-approve" ;;
    --upgrade) UPGRADE="-upgrade" ;;
    --skip-scaffold) SKIP_SCAFFOLD=true ;;
    *) echo -e "${YELLOW}⚠️ Unknown argument: $1${NC}" ;;
  esac
  shift
done

CONFIG_FILE="${GCP_GKE_DIR}/01-config/clients/${CLIENT}/${ENV}/infra/${ENV}.yaml"
LIVE_DIR="${GCP_GKE_DIR}/04-live/clients/${CLIENT}/${ENV}"

echo -e "\n${BOLD}${CYAN}================================================================${NC}"
echo -e "${BOLD}${CYAN}   GKE Platform Blueprint - Granular Infrastructure Deployment   ${NC}"
echo -e "${BOLD}${CYAN}================================================================${NC}"
echo -e "Client         : ${BOLD}${CLIENT}${NC}"
echo -e "Environment    : ${BOLD}${ENV}${NC}"
echo -e "Config File    : ${CONFIG_FILE}"
echo -e "Live Directory : ${LIVE_DIR}"
echo -e "Execution Mode : $([ "$DRY_RUN" = true ] && echo "${YELLOW}DRY-RUN (Validation Only)${NC}" || ([ "$PLAN_ONLY" = true ] && echo "${YELLOW}PLAN-ONLY${NC}" || echo "${GREEN}LIVE DEPLOYMENT${NC}"))\n"

# ==============================================================================
# PHASE 0: CONFIGURATION & PRE-FLIGHT VERIFICATION
# ==============================================================================
echo -e "${BOLD}Phase 0: Pre-Flight Verification & Configuration Parsing${NC}"

if [ ! -f "${CONFIG_FILE}" ]; then
  echo -e "${RED}❌ Error: Configuration file not found at: ${CONFIG_FILE}${NC}"
  exit 1
fi

# Parse critical fields using Python
PROJECT_ID=$(python3 -c "import yaml; cfg=yaml.safe_load(open('${CONFIG_FILE}')); print(cfg.get('gcp', {}).get('project_id', ''))")
REGION=$(python3 -c "import yaml; cfg=yaml.safe_load(open('${CONFIG_FILE}')); print(cfg.get('gcp', {}).get('region', ''))")
CLUSTER_NAME=$(python3 -c "import yaml; cfg=yaml.safe_load(open('${CONFIG_FILE}')); print(cfg.get('gke', {}).get('cluster_name', ''))")
STATE_BUCKET=$(python3 -c "import yaml; cfg=yaml.safe_load(open('${CONFIG_FILE}')); print(cfg.get('bootstrap', {}).get('state_bucket_name', ''))")

echo -e "  ✔ GCP Project ID : ${PROJECT_ID}"
echo -e "  ✔ Region         : ${REGION}"
echo -e "  ✔ Cluster Name   : ${CLUSTER_NAME}"
echo -e "  ✔ State Bucket   : ${STATE_BUCKET}"

# ==============================================================================
# PHASE 1: SCAFFOLDING GENERATION / SYNCHRONIZATION
# ==============================================================================
if [ "${SKIP_SCAFFOLD}" = false ]; then
  echo -e "\n${BOLD}Phase 1: Synchronizing Terragrunt Scaffolding${NC}"
  python3 "${GCP_GKE_DIR}/02-scripts/scaffolding/02-scaffold_client.py" "${CONFIG_FILE}"
  python3 "${GCP_GKE_DIR}/02-scripts/scaffolding/03-scaffold_jenkins.py" "${CONFIG_FILE}"
  python3 "${GCP_GKE_DIR}/02-scripts/scaffolding/04-scaffold_apps.py" "${CONFIG_FILE}"
  terragrunt hcl fmt --working-dir "${LIVE_DIR}" > /dev/null 2>&1 || true
  echo -e "  ✔ Scaffolding layout synchronized and formatted."
fi

# Verify DAG resolution
echo -e "\n${BOLD}Phase 2: Verifying Layer Dependency Graph (DAG)${NC}"
terragrunt dag graph --working-dir "${LIVE_DIR}" > /dev/null 2>&1
echo -e "  ✔ Dependency graph verified successfully."

if [ "$DRY_RUN" = true ]; then
  echo -e "\n${GREEN}${BOLD}✔ Dry-Run Validation Complete!${NC}"
  echo -e "All configurations, scaffolding templates, and dependency graphs are valid."
  echo -e "To execute a cloud deployment plan, run without ${CYAN}--dry-run${NC}."
  exit 0
fi

# ==============================================================================
# PHASE 3: BOOTSTRAP LAYER (State Bucket & API Foundation)
# ==============================================================================
echo -e "\n${BOLD}${CYAN}================================================================${NC}"
echo -e "${BOLD}Phase 3: Deploying Layer: 00-bootstrap (GCS State Bucket & APIs)${NC}"
echo -e "${BOLD}${CYAN}================================================================${NC}"

BOOTSTRAP_DIR="${LIVE_DIR}/00-bootstrap"
if [ -d "${BOOTSTRAP_DIR}" ]; then
  cd "${BOOTSTRAP_DIR}"
  
  echo "Checking GCS state bucket gs://${STATE_BUCKET}..."
  if ! gcloud storage buckets describe "gs://${STATE_BUCKET}" --project="${PROJECT_ID}" > /dev/null 2>&1; then
    if [ "$PLAN_ONLY" = true ]; then
      echo "  ⚠️ Notice: State bucket gs://${STATE_BUCKET} not accessible or not created yet (skipping creation in plan-only mode)."
    else
      echo "State bucket gs://${STATE_BUCKET} does not exist. Creating via bootstrap script..."
      bash "${GCP_GKE_DIR}/02-scripts/bootstrap/01-create-bootstrap-bucket.sh" "${PROJECT_ID}" "${STATE_BUCKET}" "${REGION}" "${CLIENT}"
    fi
  else
    echo "  ✔ Bucket gs://${STATE_BUCKET} already exists."
  fi

  terragrunt init ${UPGRADE}
  
  # Import bucket if not already in state
  terragrunt import google_storage_bucket.tf_state "${STATE_BUCKET}" > /dev/null 2>&1 || true
  
  terragrunt plan
  
  if [ "$PLAN_ONLY" = false ]; then
    if [ -z "$AUTO_APPROVE" ]; then
      read -p "⚠️  Proceed with applying 00-bootstrap? (y/N): " confirm_boot
      if [[ "$confirm_boot" != "y" && "$confirm_boot" != "Y" ]]; then
        echo -e "${RED}❌ Deployment stopped by user at 00-bootstrap.${NC}"
        exit 1
      fi
    fi
    terragrunt apply ${AUTO_APPROVE}
  fi
fi

# ==============================================================================
# PHASE 4: DOWNSTREAM INFRASTRUCTURE LAYERS
# ==============================================================================
ORDERED_LAYERS=(
  "01-network"
  "02-gke"
  "03-artifact-registry"
  "04-storage"
  "06-jenkins"
  "07-applications"
)

for LAYER in "${ORDERED_LAYERS[@]}"; do
  LAYER_DIR="${LIVE_DIR}/${LAYER}"
  if [ -d "${LAYER_DIR}" ]; then
    echo -e "\n${BOLD}${CYAN}================================================================${NC}"
    echo -e "${BOLD}Deploying Layer: ${LAYER}${NC}"
    echo -e "${BOLD}${CYAN}================================================================${NC}"
    cd "${LAYER_DIR}"
    
    terragrunt init ${UPGRADE}
    terragrunt plan
    
    if [ "$PLAN_ONLY" = false ]; then
      if [ -z "$AUTO_APPROVE" ]; then
        read -p "⚠️  Proceed with applying ${LAYER}? (y/N): " confirm_layer
        if [[ "$confirm_layer" != "y" && "$confirm_layer" != "Y" ]]; then
          echo -e "${RED}❌ Deployment stopped by user at ${LAYER}.${NC}"
          exit 1
        fi
      fi
      terragrunt apply ${AUTO_APPROVE}
    fi
  else
    echo -e "${YELLOW}⏭️  Skipping ${LAYER}: Layer directory not found.${NC}"
  fi
done

# ==============================================================================
# PHASE 5: POST-DEPLOYMENT VERIFICATION & KUBECONFIG
# ==============================================================================
if [ "$PLAN_ONLY" = false ]; then
  echo -e "\n${BOLD}${CYAN}================================================================${NC}"
  echo -e "${BOLD}Phase 5: Configuring Kubernetes Cluster Access${NC}"
  echo -e "${BOLD}${CYAN}================================================================${NC}"
  
  echo "Configuring kubectl credentials for cluster ${CLUSTER_NAME}..."
  gcloud container clusters get-credentials "${CLUSTER_NAME}" --region="${REGION}" --project="${PROJECT_ID}"
  
  echo -e "\nVerifying cluster nodes:"
  kubectl get nodes || true
  
  echo -e "\n${GREEN}${BOLD}🎉 Infrastructure deployment completed successfully for ${CLIENT} (${ENV})!${NC}\n"
else
  echo -e "\n${GREEN}${BOLD}✔ Plan execution completed successfully across all layers for ${CLIENT} (${ENV})!${NC}\n"
fi

