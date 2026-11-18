#!/usr/bin/env bash
# Install the pinned aws-eks toolchain on Ubuntu/Debian (x86_64):
# AWS CLI v2, Terraform, Terragrunt, kubectl, Helm, python3-yaml.
#
# Every download is verified against a pinned SHA-256 checksum. These versions
# must match aws-eks/08-docker/Dockerfile.
# The alternative is the tooling container: see aws-eks/08-docker/README.md.
set -Eeuo pipefail

TERRAFORM_VERSION="1.15.8"
TERRAFORM_SHA256="d25ce7b6902013ad905db3d2eab0be4cd905887fe88b81a6171b8d5503c31f3d"
TERRAGRUNT_VERSION="v1.1.2"
TERRAGRUNT_SHA256="534070d5b261a0e65b3f490479f602a8f80a0ae115e399a3786802cce658aeaa"
KUBECTL_VERSION="v1.34.13"
KUBECTL_SHA256="b4bb494e9466a7a94bb851414548bc0d3e2f8da90757e6eccc3371e648648591"
HELM_VERSION="v3.22.1"
HELM_SHA256="896cf63684a42a723d61c980369d6e588330927deb13676ca0d85006dd6da0ea"
AWSCLI_VERSION="2.41.0"
AWSCLI_SHA256="41c0e2d33e30ff34f0fcac8ec2a013d8c3b95100cf7d4bd1007302b7d4f655e5"

[[ "$(uname -m)" == "x86_64" ]] || { echo "This script supports x86_64 only." >&2; exit 1; }

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
cd "$WORK"

fetch() { # <url> <output> <sha256>
  curl -fsSL -o "$2" "$1"
  echo "$3  $2" | sha256sum -c -
}

echo "==> [1/6] System packages"
sudo apt-get update
sudo apt-get install -y curl unzip ca-certificates git python3 python3-yaml

echo "==> [2/6] AWS CLI ${AWSCLI_VERSION}"
fetch "https://awscli.amazonaws.com/awscli-exe-linux-x86_64-${AWSCLI_VERSION}.zip" awscli.zip "$AWSCLI_SHA256"
unzip -q awscli.zip
sudo ./aws/install --update

echo "==> [3/6] Terraform ${TERRAFORM_VERSION}"
fetch "https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip" terraform.zip "$TERRAFORM_SHA256"
unzip -q -o terraform.zip terraform
sudo install -m 0755 terraform /usr/local/bin/terraform

echo "==> [4/6] Terragrunt ${TERRAGRUNT_VERSION}"
fetch "https://github.com/gruntwork-io/terragrunt/releases/download/${TERRAGRUNT_VERSION}/terragrunt_linux_amd64" terragrunt "$TERRAGRUNT_SHA256"
sudo install -m 0755 terragrunt /usr/local/bin/terragrunt

echo "==> [5/6] kubectl ${KUBECTL_VERSION}"
fetch "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl" kubectl "$KUBECTL_SHA256"
sudo install -m 0755 kubectl /usr/local/bin/kubectl

echo "==> [6/6] Helm ${HELM_VERSION}"
fetch "https://get.helm.sh/helm-${HELM_VERSION}-linux-amd64.tar.gz" helm.tgz "$HELM_SHA256"
tar -xzf helm.tgz linux-amd64/helm
sudo install -m 0755 linux-amd64/helm /usr/local/bin/helm

echo "======================================================================="
echo "Installed: $(aws --version 2>&1 | cut -d' ' -f1), terraform ${TERRAFORM_VERSION}, terragrunt ${TERRAGRUNT_VERSION}, kubectl ${KUBECTL_VERSION}, helm ${HELM_VERSION}"
echo "Next steps:"
echo "  - aws configure sso   (create the profile named in aws.profile of your infra YAML)"
echo "  - aws sso login --profile <profile>"
echo "======================================================================="
