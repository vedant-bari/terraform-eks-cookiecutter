# Terraform + Terragrunt AWS EKS Platform

This repository provisions an AWS platform foundation using Terraform modules and Terragrunt environment configuration. The current `client-a/dev` configuration creates Terraform state infrastructure, a VPC, an Amazon EKS cluster, and—in its current in-progress form—a bastion security group.

## What is provisioned

The deployment workflow runs these components in order:

1. **Bootstrap**: an S3 bucket for Terraform state and a KMS key. DynamoDB locking is supported by the module but disabled by default; the generated backend uses S3 lockfiles.
2. **VPC**: a VPC with three public and three private subnets across `ap-south-1a`, `ap-south-1b`, and `ap-south-1c`, plus NAT gateways when enabled in configuration.
3. **Bastion**: currently creates only a security group from the configured ingress/egress rules. The EC2 instance and Terragrunt wiring are not yet implemented.
4. **EKS**: an EKS cluster with managed `core_nodes` and `app_nodes` node groups, control-plane logging, and AWS-managed CoreDNS, kube-proxy, and VPC CNI add-ons.

The included Helm chart is a sample NGINX workload with an ALB ingress and EFS persistent volume claim. It requires an existing EFS filesystem plus the AWS Load Balancer Controller and EFS CSI driver; those dependencies are not provisioned by this repository.

## Repository layout

```text
01-bootstrap/                         # State bucket and KMS Terraform module entrypoint
02-modules/
  01-bootstrap/                       # S3, KMS, optional DynamoDB lock table
  02-vpc/                             # terraform-aws-modules/vpc/aws wrapper
  03-bastion/                         # Bastion security-group work in progress
  04-eks/                             # terraform-aws-modules/eks/aws wrapper
03-live/
  root.hcl                            # Generated AWS provider and S3 backend
  clients/client-a/dev/               # VPC, bastion, and EKS Terragrunt stacks
12-platform-config/clients/client-a/
  dev.yaml                            # Environment-specific settings
13-kubernetes-apps/test-app/          # Sample Helm chart
scripts/                              # Prerequisite, validation, deploy, and destroy helpers
```

## Prerequisites

- An AWS account and credentials with permission to create the configured resources.
- AWS CLI v2, Terraform, Terragrunt, `kubectl`, and Helm.
- The AWS CLI configured for the target account:

  ```bash
  aws configure
  aws sts get-caller-identity
  ```

On Ubuntu/Debian, install the tooling with:

```bash
./scripts/install-prerequisites.sh
```

The installer uses `sudo`, downloads current tool releases, and changes system-wide binaries; review it before running it.

You can check AWS and EKS API access with:

```bash
./scripts/precheck.sh
```

## Configure an environment

Edit `12-platform-config/clients/client-a/dev.yaml` before deployment. In particular, set:

- `client.account_id`, `client.region`, and resource names.
- VPC CIDRs and availability zones appropriate for the region.
- EKS node group sizing and instance types.
- A globally unique `bootstrap.bucket_name`.
- Bastion ingress rules restricted to trusted CIDRs. Do not keep the example password in source control; it is not currently used because the bastion EC2 instance is not implemented.

The state bucket name must be unique across all AWS accounts. Bootstrap state is initially local, so retain that local state securely after creation.

## Deploy with the script

Run deployment from the repository root. The script takes a client name and environment matching the configuration path.

```bash
./scripts/deploy-env.sh client-a dev
```

For each stage, the script runs `terragrunt init`, `validate`, and `plan`, then asks for confirmation before applying. After EKS deploys, it runs `aws eks update-kubeconfig` and prints a command to verify nodes.

The intended sequence is:

```text
bootstrap → 02-vpc → 03-bastion → 04-eks → kubeconfig
```

> **Current limitation:** `03-bastion` is included in the script but is incomplete, so the deployment will fail when it reaches that stage. Until it is implemented, deploy bootstrap, VPC, and EKS manually as shown below, or remove `03-bastion` from the script's `COMPONENTS` array.

### How `deploy-env.sh` works

`scripts/deploy-env.sh` is an interactive wrapper around Terragrunt. Its first two positional arguments are the client name and environment:

```bash
./scripts/deploy-env.sh <client-name> <environment>
```

For `./scripts/deploy-env.sh client-a dev`, it sets its working paths to the following locations:

| Stage | Path | Action |
| --- | --- | --- |
| Bootstrap | `01-bootstrap/clients/client-a/dev` | Creates the state bucket and KMS key. |
| VPC | `03-live/clients/client-a/dev/02-vpc` | Creates or adopts the configured VPC. |
| Bastion | `03-live/clients/client-a/dev/03-bastion` | Runs only when that directory exists. Currently incomplete. |
| EKS | `03-live/clients/client-a/dev/04-eks` | Creates the EKS cluster and managed node groups. |

For bootstrap and every existing live component, the script performs this sequence:

```text
terragrunt init → terragrunt validate → terragrunt plan → confirmation prompt → terragrunt apply -auto-approve
```

`-auto-approve` is safe here only because the script prompts after displaying the plan. The script exits immediately on a command failure (`set -e`) or if you answer anything other than `y` or `Y` at a prompt.

After the infrastructure loop, it reads `region` and `cluster_name` from `12-platform-config/clients/<client-name>/<environment>.yaml` and runs:

```bash
aws eks update-kubeconfig --region <region> --name <cluster-name>
```

Run the script only from the repository root. It uses the current directory (`pwd`) as its base path, so running it from another directory will cause its relative paths to fail.

## Manual deployment

From the repository root:

```bash
cd 01-bootstrap/clients/client-a/dev
terragrunt init
terragrunt validate
terragrunt plan
terragrunt apply
```

Then deploy the VPC:

```bash
cd ../../../../03-live/clients/client-a/dev/02-vpc
terragrunt init
terragrunt validate
terragrunt plan
terragrunt apply
```

Then deploy EKS:

```bash
cd ../04-eks
terragrunt init
terragrunt validate
terragrunt plan
terragrunt apply
```

Configure `kubectl` after EKS is ready:

```bash
aws eks update-kubeconfig --region ap-south-1 --name eks-client-a-dev
kubectl get nodes
```

## Deploy the sample Helm chart

After installing the required controllers and setting a real EFS file-system ID in `13-kubernetes-apps/test-app/values.yaml`:

```bash
helm upgrade --install eks-test-app ./13-kubernetes-apps/test-app
kubectl get pods,svc,ingress,pv,pvc
```

## Destroy

The destroy helper is interactive:

```bash
./scripts/destroy-env.sh client-a dev
```

It currently destroys EKS, then VPC, then bootstrap. Do **not** use it after creating bastion resources: it does not include `03-bastion`, and the remaining security group can prevent VPC deletion. Remove bastion resources first or update the destroy order to run bastion before VPC. Destroying bootstrap deletes the Terraform state bucket and KMS key; use this only when permanently removing the environment.

## Security and operational notes

- The EKS API endpoint is publicly accessible in the current module configuration. Restrict it with an explicit CIDR allowlist before production use.
- Avoid `0.0.0.0/0` SSH ingress and never commit real passwords or credentials to YAML.
- The bootstrap S3 bucket has `force_destroy = true`; all object versions can be removed during destruction.
- Pin container image tags instead of using mutable tags such as `latest`.
- Run formatting and validation before a pull request:

  ```bash
  terraform fmt -check -recursive
  terragrunt hcl format --check
  helm lint 13-kubernetes-apps/test-app
  ```

## Status

The VPC and EKS stacks are the implemented infrastructure path. Bastion support, VPC flow logs/endpoints, private EKS endpoint access, subnet discovery tags, IAM/IRSA configuration, and the Helm chart's AWS dependencies are future work needed for a production-ready platform.
