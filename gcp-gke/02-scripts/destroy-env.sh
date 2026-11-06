#!/usr/bin/env bash
# ==============================================================================
# GKE Platform Blueprint - Automated Infrastructure Teardown / Destruction
# ==============================================================================
# Usage:
#   ./gcp-gke/02-scripts/destroy-env.sh <client-name> <environment> [options]
#
# Options:
#   --plan-only       Run Terragrunt plan -destroy without deleting
#   --auto-approve    Destroy changes without interactive confirmation prompts
#
# Example:
#   ./gcp-gke/02-scripts/destroy-env.sh amex prod --plan-only
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

if [ "$#" -lt 2 ]; then
  echo -e "${RED}❌ Error: Missing required arguments.${NC}"
  echo -e "Usage: $0 <client-name> <environment> [--plan-only] [--auto-approve]"
  echo -e "Example: $0 amex prod --plan-only"
  exit 1
fi

CLIENT="$1"
ENV="$2"
shift 2

PLAN_ONLY=false
AUTO_APPROVE=""

while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --plan-only) PLAN_ONLY=true ;;
    --auto-approve) AUTO_APPROVE="-auto-approve" ;;
    *) echo -e "${YELLOW}⚠️ Unknown argument: $1${NC}" ;;
  esac
  shift
done

LIVE_DIR="${GCP_GKE_DIR}/04-live/clients/${CLIENT}/${ENV}"

echo -e "\n${BOLD}${RED}================================================================${NC}"
echo -e "${BOLD}${RED}   ⚠️  GKE Platform Blueprint - Infrastructure Destruction       ${NC}"
echo -e "${BOLD}${RED}================================================================${NC}"
echo -e "Client         : ${BOLD}${CLIENT}${NC}"
echo -e "Environment    : ${BOLD}${ENV}${NC}"
echo -e "Live Directory : ${LIVE_DIR}"
echo -e "Execution Mode : $([ "$PLAN_ONLY" = true ] && echo "${YELLOW}PLAN-DESTROY ONLY${NC}" || echo "${RED}LIVE DESTRUCTION${NC}")\n"

# REVERSE DEPENDENCY ORDER
REVERSE_LAYERS=(
  "07-applications"
  "06-jenkins"
  "04-storage"
  "03-artifact-registry"
  "02-gke"
  "01-network"
)

for LAYER in "${REVERSE_LAYERS[@]}"; do
  LAYER_DIR="${LIVE_DIR}/${LAYER}"
  if [ -d "${LAYER_DIR}" ]; then
    echo -e "\n${BOLD}${RED}================================================================${NC}"
    echo -e "${BOLD}Destruction Phase: ${LAYER}${NC}"
    echo -e "${BOLD}${RED}================================================================${NC}"
    cd "${LAYER_DIR}"
    
    terragrunt init
    terragrunt plan -- -destroy
    
    if [ "$PLAN_ONLY" = false ]; then
      if [ -z "$AUTO_APPROVE" ]; then
        read -p "🛑 Are you sure you want to DESTROY ${LAYER}? (y/N): " confirm_destroy
        if [[ "$confirm_destroy" != "y" && "$confirm_destroy" != "Y" ]]; then
          echo -e "${RED}❌ Destruction stopped by user at ${LAYER}.${NC}"
          exit 1
        fi
      fi
      terragrunt destroy ${AUTO_APPROVE}
    fi
  else
    echo -e "${YELLOW}⏭️  Skipping ${LAYER}: Layer directory not found.${NC}"
  fi
done

echo -e "\n${GREEN}${BOLD}✔ Infrastructure teardown sequence completed for ${CLIENT} (${ENV})!${NC}\n"

