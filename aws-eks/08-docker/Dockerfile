# aws-eks tooling image: AWS CLI v2, Terraform, Terragrunt, kubectl, Helm, Python (PyYAML).
# Every download is verified against a pinned SHA-256. Versions must match
# aws-eks/02-scripts/bootstrap/install-prerequisites.sh.
FROM python:3.11-slim

ARG TERRAFORM_VERSION=1.15.8
ARG TERRAFORM_SHA256=d25ce7b6902013ad905db3d2eab0be4cd905887fe88b81a6171b8d5503c31f3d
ARG TERRAGRUNT_VERSION=v1.1.2
ARG TERRAGRUNT_SHA256=534070d5b261a0e65b3f490479f602a8f80a0ae115e399a3786802cce658aeaa
ARG KUBECTL_VERSION=v1.34.13
ARG KUBECTL_SHA256=b4bb494e9466a7a94bb851414548bc0d3e2f8da90757e6eccc3371e648648591
ARG HELM_VERSION=v3.22.1
ARG HELM_SHA256=896cf63684a42a723d61c980369d6e588330927deb13676ca0d85006dd6da0ea
ARG AWSCLI_VERSION=2.41.0
ARG AWSCLI_SHA256=41c0e2d33e30ff34f0fcac8ec2a013d8c3b95100cf7d4bd1007302b7d4f655e5

WORKDIR /workspace

RUN apt-get update \
    && apt-get install -y --no-install-recommends curl unzip git ca-certificates less groff \
    && rm -rf /var/lib/apt/lists/*

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN set -eux; cd /tmp; \
    curl -fsSL -o awscli.zip "https://awscli.amazonaws.com/awscli-exe-linux-x86_64-${AWSCLI_VERSION}.zip"; \
    echo "${AWSCLI_SHA256}  awscli.zip" | sha256sum -c -; \
    unzip -q awscli.zip; ./aws/install; rm -rf aws awscli.zip; \
    \
    curl -fsSL -o terraform.zip "https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip"; \
    echo "${TERRAFORM_SHA256}  terraform.zip" | sha256sum -c -; \
    unzip -q terraform.zip terraform -d /usr/local/bin; rm terraform.zip; \
    \
    curl -fsSL -o /usr/local/bin/terragrunt "https://github.com/gruntwork-io/terragrunt/releases/download/${TERRAGRUNT_VERSION}/terragrunt_linux_amd64"; \
    echo "${TERRAGRUNT_SHA256}  /usr/local/bin/terragrunt" | sha256sum -c -; \
    chmod 0755 /usr/local/bin/terragrunt; \
    \
    curl -fsSL -o /usr/local/bin/kubectl "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl"; \
    echo "${KUBECTL_SHA256}  /usr/local/bin/kubectl" | sha256sum -c -; \
    chmod 0755 /usr/local/bin/kubectl; \
    \
    curl -fsSL -o helm.tgz "https://get.helm.sh/helm-${HELM_VERSION}-linux-amd64.tar.gz"; \
    echo "${HELM_SHA256}  helm.tgz" | sha256sum -c -; \
    tar -xzf helm.tgz -C /usr/local/bin --strip-components=1 linux-amd64/helm; rm helm.tgz

RUN pip install --no-cache-dir pyyaml==6.0.2 requests==2.32.3

# The repository is bind-mounted at /workspace; allow git to read it.
RUN git config --system --add safe.directory /workspace

CMD ["bash"]
