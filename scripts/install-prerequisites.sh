#!/usr/bin/env bash

set -euo pipefail

echo "====================================="
echo "Installing EKS Platform Prerequisites"
echo "====================================="

sudo apt-get update

sudo apt-get install -y \
    curl \
    unzip \
    jq \
    git \
    tree \
    make \
    vim \
    ca-certificates \
    gnupg \
    software-properties-common

echo ""
echo "Installing AWS CLI v2..."

cd /tmp

curl -s "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o awscliv2.zip

unzip -q -o awscliv2.zip

sudo ./aws/install --update

rm -rf aws awscliv2.zip

echo ""
echo "Installing Terraform..."

wget -qO- https://apt.releases.hashicorp.com/gpg \
    | gpg --dearmor \
    | sudo tee /usr/share/keyrings/hashicorp-archive-keyring.gpg >/dev/null

echo \
"deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] \
https://apt.releases.hashicorp.com \
$(lsb_release -cs) main" \
| sudo tee /etc/apt/sources.list.d/hashicorp.list

sudo apt-get update

sudo apt-get install -y terraform

echo ""
echo "Installing Terragrunt..."

TG_VERSION=$(curl -s https://api.github.com/repos/gruntwork-io/terragrunt/releases/latest | jq -r '.tag_name')

sudo curl -L \
  "https://github.com/gruntwork-io/terragrunt/releases/download/${TG_VERSION}/terragrunt_linux_amd64" \
  -o /usr/local/bin/terragrunt

sudo chmod +x /usr/local/bin/terragrunt

echo ""
echo "Installing kubectl..."

KUBECTL_VERSION=$(curl -L -s https://dl.k8s.io/release/stable.txt)

curl -LO "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl"

sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

rm kubectl

echo ""
echo "Installing Helm..."

curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

echo ""
echo "Installing eksctl..."

ARCH=amd64
PLATFORM=$(uname -s)_${ARCH}

curl -sLO \
"https://github.com/eksctl-io/eksctl/releases/latest/download/eksctl_${PLATFORM}.tar.gz"

tar -xzf eksctl_${PLATFORM}.tar.gz -C /tmp

sudo mv /tmp/eksctl /usr/local/bin

rm eksctl_${PLATFORM}.tar.gz

echo ""
echo "Installing yq..."

YQ_VERSION=$(curl -s https://api.github.com/repos/mikefarah/yq/releases/latest | jq -r '.tag_name')

sudo wget -q \
"https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/yq_linux_amd64" \
-O /usr/local/bin/yq

sudo chmod +x /usr/local/bin/yq

echo ""
echo "====================================="
echo "Installation Complete"
echo "====================================="

echo ""
echo "Installed Versions:"
echo ""

aws --version
terraform version | head -n1
terragrunt --version
kubectl version --client
helm version --short
eksctl version
yq --version

echo ""
echo "Next Steps:"
echo ""
echo "1. Configure AWS credentials:"
echo "   aws configure"
echo ""
echo "2. Verify AWS access:"
echo "   aws sts get-caller-identity"
echo ""
echo "3. Bootstrap backend:"
echo "   cd bootstrap/dev"
echo "   terragrunt apply"
echo ""
echo "4. Deploy infrastructure:"
echo "   cd live/dev"
echo "   terragrunt run-all apply"