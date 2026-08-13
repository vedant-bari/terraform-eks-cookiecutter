#!/bin/bash
set -e

# Check if required arguments are provided
if [ -z "$1" ] || [ -z "$2" ] || [ -z "$3" ]; then
  echo "❌ Usage: ./scripts/deploy-app.sh <client-name> <environment> <app-name>"
  echo "   Example: ./scripts/deploy-app.sh client-a dev orders-api"
  exit 1
fi

CLIENT=$1
ENV=$2
APP_NAME=$3
BASE_DIR="$(pwd)"
APP_DIR="$BASE_DIR/13-kubernetes-apps/$CLIENT/$APP_NAME"
PLATFORM_CONFIG_FILE="$BASE_DIR/12-platform-config/clients/$CLIENT/infra/$ENV.yaml"
GENERIC_KUSTOMIZE_TEMPLATE="$BASE_DIR/13-kubernetes-apps/generic-kustomization.template.yaml"
APP_VALUES_FILE="$BASE_DIR/12-platform-config/clients/$CLIENT/applications/${APP_NAME}.${ENV}.yaml"

echo "🚀 Starting Application Deployment for $APP_NAME ($CLIENT / $ENV)..."

# ==========================================
# PHASE 1: PREREQUISITE CHECKS
# ==========================================
echo "======================================================="
echo "🔎 PHASE 1: Checking prerequisites..."
echo "======================================================="

if ! command -v kubectl &> /dev/null; then
    echo "❌ kubectl could not be found. Please install it first."
    exit 1
fi

if ! command -v kustomize &> /dev/null; then
    echo "❌ kustomize could not be found. Please install it first."
    exit 1
fi

if ! command -v envsubst &> /dev/null; then
    echo "❌ envsubst could not be found. Please install the 'gettext' package."
    exit 1
fi

if ! command -v yq &> /dev/null; then
    echo "❌ yq could not be found. Please run ./scripts/install-prerequisites.sh first."
    exit 1
fi

if [ ! -d "$APP_DIR" ]; then
  echo "❌ Application directory not found at: $APP_DIR"
  exit 1
fi

if [ ! -f "$PLATFORM_CONFIG_FILE" ]; then
  echo "❌ Platform config file not found at: $PLATFORM_CONFIG_FILE"
  exit 1
fi

if [ ! -f "$APP_VALUES_FILE" ]; then
  echo "❌ Application values file not found at: $APP_VALUES_FILE"
  exit 1
fi

if [ ! -f "$GENERIC_KUSTOMIZE_TEMPLATE" ]; then
  echo "❌ Generic Kustomize template file not found at: $GENERIC_KUSTOMIZE_TEMPLATE"
  exit 1
fi

echo "✅ Prerequisites met."

# ==========================================
# PHASE 2: CONNECT TO CLUSTER
# ==========================================
echo "======================================================="
echo "🔌 PHASE 2: Connecting to EKS Cluster"
echo "======================================================="
REGION=$(yq e '.region' "$PLATFORM_CONFIG_FILE")
CLUSTER_NAME=$(yq e '.cluster_name' "$PLATFORM_CONFIG_FILE")

echo "Updating kubeconfig for cluster '$CLUSTER_NAME' in region '$REGION'..."
aws eks update-kubeconfig --region "$REGION" --name "$CLUSTER_NAME"

echo "Verifying cluster connectivity..."
kubectl cluster-info > /dev/null
echo "✅ Successfully connected to the cluster."

# ==========================================
# PHASE 3: DEPLOY APPLICATION
# ==========================================
echo "======================================================="
echo "📦 PHASE 3: Deploying $APP_NAME with Kustomize"
echo "======================================================="
cd "$APP_DIR"

# Copy the generic template to the application directory for processing
echo "Copying generic kustomization template to $APP_DIR/kustomization.template.yaml..."
cp "$GENERIC_KUSTOMIZE_TEMPLATE" "$APP_DIR/kustomization.template.yaml"

# Read the namespace from the application's values.yaml file
NAMESPACE=$(yq e '.namespace' "$APP_VALUES_FILE")

if [ -z "$NAMESPACE" ] || [ "$NAMESPACE" == "null" ]; then
  echo "❌ 'namespace' not found or is empty in values.yaml for application '$APP_NAME'."
  exit 1
fi

# Dynamically generate kustomization.yaml from template
echo "Generating kustomization.yaml from template..."
export APP_NAME
# Calculate the relative path from the app overlay dir to the values file
export VALUES_FILE
VALUES_FILE=$(realpath --relative-to="$APP_DIR" "$APP_VALUES_FILE")
envsubst < kustomization.template.yaml > kustomization.yaml

echo "Ensuring namespace '$NAMESPACE' exists..."
kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

echo "Building and applying Kubernetes manifests..."
kustomize build . | kubectl apply -n "$NAMESPACE" -f -

# Clean up the generated file
rm kustomization.yaml kustomization.template.yaml

echo "✅ Application deployment for '$APP_NAME' initiated successfully!"
echo "   Run 'kubectl get pods -n $NAMESPACE' to check the status."