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
BASE_DIR=$(pwd)
APP_DIR="$BASE_DIR/13-kubernetes-apps/$CLIENT/$APP_NAME"
CONFIG_FILE="$BASE_DIR/12-platform-config/clients/$CLIENT/$ENV.yaml"

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

if ! command -v yq &> /dev/null; then
    echo "❌ yq could not be found. Please run ./scripts/install-prerequisites.sh first."
    exit 1
fi

if [ ! -d "$APP_DIR" ]; then
  echo "❌ Application directory not found at: $APP_DIR"
  exit 1
fi

if [ ! -f "$CONFIG_FILE" ]; then
  echo "❌ Platform config file not found at: $CONFIG_FILE"
  exit 1
fi

echo "✅ Prerequisites met."

# ==========================================
# PHASE 2: CONNECT TO CLUSTER
# ==========================================
echo "======================================================="
echo "🔌 PHASE 2: Connecting to EKS Cluster"
echo "======================================================="
REGION=$(grep 'region:' "$CONFIG_FILE" | awk '{print $2}' | tr -d '"')
CLUSTER_NAME=$(grep 'cluster_name:' "$CONFIG_FILE" | awk '{print $2}' | tr -d '"')

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

# Read the namespace from the application's values.yaml file
NAMESPACE=$(yq e '.namespace' values.yaml)

if [ -z "$NAMESPACE" ] || [ "$NAMESPACE" == "null" ]; then
  echo "❌ 'namespace' not found or is empty in values.yaml for application '$APP_NAME'."
  exit 1
fi

echo "Ensuring namespace '$NAMESPACE' exists..."
kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

echo "Building and applying Kubernetes manifests..."
kustomize build . | kubectl apply -f -

echo "✅ Application deployment for '$APP_NAME' initiated successfully!"
echo "   Run 'kubectl get pods -n $NAMESPACE' to check the status."