#!/bin/bash
set -e

# Check if required arguments are provided
if [ -z "$1" ] || [ -z "$2" ]; then
  echo "❌ Usage: ./scripts/deploy-env.sh <client-name> <environment>"
  echo "   Example: ./scripts/deploy-env.sh client-a dev"
  exit 1
fi

CLIENT=$1
ENV=$2
BASE_DIR=$(pwd)

# Define the exact order of creation
COMPONENTS=("02-vpc" "03-bastion" "04-eks" "05-ebs-csi" "06-efs-csi" "07-monitoring" "08-logging")

echo "🚀 Starting Granular Infrastructure Deployment for $CLIENT ($ENV)..."

# ==========================================
# PHASE 0: BOOTSTRAP
# ==========================================
echo "======================================================="
echo "📦 PHASE 0: Bootstrap (S3 & KMS)"
echo "======================================================="
cd "$BASE_DIR/01-bootstrap/clients/$CLIENT/$ENV"
terragrunt init
terragrunt validate
terragrunt plan

echo ""
read -p "⚠️  Proceed with Bootstrap creation? (y/n): " confirm_boot
if [[ "$confirm_boot" != "y" && "$confirm_boot" != "Y" ]]; then
  echo "❌ Deployment stopped by user at Bootstrap phase."
  exit 1
fi
terragrunt apply -auto-approve


# ==========================================
# PHASE 1 & 2: LIVE INFRASTRUCTURE LOOP
# ==========================================
for COMP in "${COMPONENTS[@]}"; do
  COMP_DIR="$BASE_DIR/03-live/clients/$CLIENT/$ENV/$COMP"
  
  if [ -d "$COMP_DIR" ]; then
    echo "======================================================="
    echo "🏗️  BUILDING COMPONENT: $COMP"
    echo "======================================================="
    cd "$COMP_DIR"
    terragrunt init
    terragrunt validate
    terragrunt plan
    
    echo ""
    read -p "⚠️  Proceed with applying $COMP? (y/n): " confirm_comp
    if [[ "$confirm_comp" != "y" && "$confirm_comp" != "Y" ]]; then
      echo "❌ Deployment stopped by user at $COMP."
      exit 1
    fi
    terragrunt apply -auto-approve
  else
    echo "⏭️  Skipping $COMP: Directory not found."
  fi
done

# ==========================================
# PHASE 3: KUBECONFIG
# ==========================================
echo "======================================================="
echo "🔌 PHASE 3: Connecting to Kubernetes"
echo "======================================================="
REGION=$(grep 'region:' "$BASE_DIR/12-platform-config/clients/$CLIENT/$ENV.yaml" | awk '{print $2}' | tr -d '"')
CLUSTER_NAME=$(grep 'cluster_name:' "$BASE_DIR/12-platform-config/clients/$CLIENT/$ENV.yaml" | awk '{print $2}' | tr -d '"')

aws eks update-kubeconfig --region $REGION --name $CLUSTER_NAME

echo "✅ Granular Deployment Complete! Run 'kubectl get nodes' to verify."
