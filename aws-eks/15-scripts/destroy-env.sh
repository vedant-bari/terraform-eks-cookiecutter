#!/bin/bash
set -e

# Check if required arguments are provided
if [ -z "$1" ] || [ -z "$2" ]; then
  echo "❌ Usage: ./scripts/destroy-env.sh <client-name> <environment>"
  echo "   Example: ./scripts/destroy-env.sh client-a dev"
  exit 1
fi

CLIENT=$1
ENV=$2
BASE_DIR=$(pwd)

# Define the exact order of destruction (MUST BE REVERSED)
COMPONENTS=("02-vpc")

echo "⚠️  WARNING: Starting Granular Infrastructure DESTRUCTION for $CLIENT ($ENV)..."

# ==========================================
# PHASE 1: LIVE INFRASTRUCTURE LOOP
# ==========================================
for COMP in "${COMPONENTS[@]}"; do
  COMP_DIR="$BASE_DIR/03-live/clients/$CLIENT/$ENV/$COMP"
  
  if [ -d "$COMP_DIR" ]; then
    echo "======================================================="
    echo "🧨 DESTROYING COMPONENT: $COMP"
    echo "======================================================="
    cd "$COMP_DIR"
    terragrunt init
    terragrunt validate
    
    # NEW: Using the -- separator to pass the flag to Terraform
    terragrunt plan -- -destroy
    
    echo ""
    read -p "🛑 Are you sure you want to DESTROY $COMP? (y/n): " confirm_comp
    if [[ "$confirm_comp" != "y" && "$confirm_comp" != "Y" ]]; then
      echo "❌ Destruction stopped by user at $COMP."
      exit 1
    fi
    terragrunt destroy -auto-approve
  else
    echo "⏭️  Skipping $COMP: Directory not found."
  fi
done

# ==========================================
# PHASE 2: BOOTSTRAP
# ==========================================
echo "======================================================="
echo "🗑️  PHASE 2: Bootstrap (S3 State Bucket & KMS)"
echo "======================================================="
cd "$BASE_DIR/01-bootstrap/clients/$CLIENT/$ENV"
terragrunt init
terragrunt validate

# NEW: Using the -- separator to pass the flag to Terraform
terragrunt plan -- -destroy

echo ""
read -p "🛑 Are you sure you want to DESTROY the Bootstrap layer? (y/n): " confirm_boot
if [[ "$confirm_boot" != "y" && "$confirm_boot" != "Y" ]]; then
  echo "❌ Bootstrap destruction stopped by user."
  exit 1
fi
terragrunt destroy -auto-approve

echo "✅ Granular Infrastructure Teardown Complete for $CLIENT ($ENV)."
