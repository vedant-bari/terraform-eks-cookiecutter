# aws-eks tooling container

This image contains the pinned toolchain for the aws-eks platform. Every download is checked against a pinned SHA-256.

| Tool | Version |
|---|---|
| AWS CLI v2 | 2.41.0 |
| Terraform | 1.15.8 |
| Terragrunt | v1.1.2 |
| kubectl | v1.34.13 |
| Helm | v3.22.1 |
| Python | 3.11, with PyYAML |

When you bump a version, update both this image and `02-scripts/bootstrap/install-prerequisites.sh`, including the SHA-256 value. Align kubectl with the EKS minor version in `01-config/.../infra/<env>.yaml`; kubectl supports ±1 minor version of skew.

## Usage

```bash
cd aws-eks/08-docker
docker compose build
docker compose run --rm infra-runner
```

Inside the container, the repository root is mounted at `/workspace`, and your host `~/.aws` is mounted read-write so the SSO token cache works.

```bash
aws sso login --profile <profile from aws.profile>
./aws-eks/02-scripts/bootstrap/01-create-bootstrap-bucket.sh amex prod
```

No GKE-style auth plugin is needed. The Kubernetes and Helm providers, and `aws eks update-kubeconfig`, get their tokens from `aws eks get-token`, which is built into the AWS CLI.
