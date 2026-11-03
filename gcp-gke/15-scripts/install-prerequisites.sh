#!/bin/bash
set -e

# ==============================================================================
# GCP PREREQUISITES INSTALLATION SCRIPT FOR UBUNTU 20
# ==============================================================================

echo "======================================================================="
echo "🚀 Installing Google Cloud CLI and Prerequisite Tools..."
echo "======================================================================="

# Step 1: Install prerequisite packages
echo "📦 [1/4] Installing transport and security dependencies..."
sudo apt-get update
sudo apt-get install apt-transport-https ca-certificates gnupg curl -y

# Step 2: Import the Google Cloud public key
echo "🔑 [2/4] Importing Google Cloud public security key..."
curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo tee /usr/share/keyrings/cloud.google.gpg > /dev/null

# Step 3: Add the Google Cloud SDK distribution source
echo "📂 [3/4] Adding Google Cloud SDK repository source list..."
echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | sudo tee /etc/apt/sources.list.d/google-cloud-sdk.list

# Step 4: Install the Google Cloud CLI
echo "⚙️  [4/4] Updating package lists and installing google-cloud-cli..."
sudo apt-get update
sudo apt-get install google-cloud-cli -y

echo "======================================================================="
echo "✅ Installation Complete! Google Cloud CLI is ready to use."
echo "👉 Next steps:"
echo "   - Run 'gcloud init' to configure your account and region."
echo "   - Run 'gcloud auth application-default login' for Terraform/Terragrunt."
echo "======================================================================="