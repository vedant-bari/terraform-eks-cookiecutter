# Terraform + Terragrunt AWS EKS Platform

This repository provisions an AWS platform foundation using Terraform modules and Terragrunt environment configuration. The current `client-a/dev` configuration creates Terraform state infrastructure, a VPC, an Amazon EKS cluster, and—in its current in-progress form—a bastion security group.

## What is provisioned

The deployment workflow runs these components in order:

1. **Bootstrap**: an S3 bucket for Terraform state and a KMS key. DynamoDB locking is supported by the module but disabled by default; the generated backend uses S3 lockfiles.
2. **VPC**: a VPC with three public and three private subnets across `ap-south-1a`, `ap-south-1b`, and `ap-south-1c`, plus NAT gateways when enabled in configuration.
3. **Bastion**: an Amazon Linux 2023 EC2 host in the first public VPC subnet, with a configurable security group and an SSM-capable IAM instance profile.
4. **EKS**: an EKS cluster with managed `core_nodes` and `app_nodes` node groups, control-plane logging, and AWS-managed CoreDNS, kube-proxy, and VPC CNI add-ons.
5. **EBS CSI**: the AWS EBS CSI managed add-on, its IRSA role, and an `ebs-gp3` StorageClass for dynamically provisioned encrypted gp3 volumes.
6. **EFS CSI**: an encrypted EFS file system with private-subnet mount targets when configured to create one, or an existing EFS file system when configured to adopt one, plus an `efs-sc` RWX StorageClass.

The included Helm chart is a sample NGINX workload with an ALB ingress and EFS persistent volume claim. It requires an existing EFS filesystem plus the AWS Load Balancer Controller and EFS CSI driver; those dependencies are not provisioned by this repository.

## Repository layout

```text
01-bootstrap/                         # State bucket and KMS Terraform module entrypoint
02-modules/
  01-bootstrap/                       # S3, KMS, optional DynamoDB lock table
  02-vpc/                             # terraform-aws-modules/vpc/aws wrapper
  03-bastion/                         # Bastion EC2 host, security group, and IAM profile
  04-eks/                             # terraform-aws-modules/eks/aws wrapper
  05-ebs-csi/                         # EBS CSI add-on, IRSA role, and gp3 StorageClass
  06-efs-csi/                         # EFS CSI add-on, IRSA role, EFS, and RWX StorageClass
  07-monitoring/                      # kube-prometheus-stack Helm release
  08-logging/                         # Loki, Alloy log collection, and Grafana log integration
03-live/
  root.hcl                            # Generated AWS provider and S3 backend
  clients/client-a/dev/               # VPC, bastion, EKS, EBS CSI, and EFS CSI Terragrunt stacks
12-platform-config/clients/client-a/applications/
  openmetadata.dev.yaml               # OpenMetadata application values for dev
  nginx.dev.yaml                      # Nginx application values for dev
  node.js.dev.yaml                    # Node.js application values for dev
12-platform-config/clients/client-a/infra/
  dev.yaml                            # Environment-specific infrastructure settings
13-kubernetes-apps/client-a/
  openmetadata/                       # Application directory (uses generic Kustomization template)
  nginx/                              # Application directory (uses generic Kustomization template)
  test-app/                           # Sample Helm chart
  node.js/                            # Application directory (uses generic Kustomization template)
13-kubernetes-apps/generic-kustomization.template.yaml # Generic Kustomization template for all applications
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
- Bastion ingress rules restricted to trusted CIDRs. Set `bastion.password` to `null` to use SSM Session Manager without creating a password-authenticated user.

The state bucket name must be unique across all AWS accounts. Bootstrap state is initially local, so retain that local state securely after creation.

## Deploy with the script

Run deployment from the repository root. The script takes a client name and environment matching the configuration path.

```bash
./scripts/deploy-env.sh client-a dev
```

For each stage, the script runs `terragrunt init`, `validate`, and `plan`, then asks for confirmation before applying. After EKS deploys, it runs `aws eks update-kubeconfig` and prints a command to verify nodes.

The intended sequence is:

```text
bootstrap → 02-vpc → 03-bastion → 04-eks → 05-ebs-csi → 06-efs-csi → 07-monitoring → 08-logging → kubeconfig
```

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
| Bastion | `03-live/clients/client-a/dev/03-bastion` | Creates the bastion host in the VPC's first public subnet. |
| EKS | `03-live/clients/client-a/dev/04-eks` | Creates the EKS cluster and managed node groups. |
| EBS CSI | `03-live/clients/client-a/dev/05-ebs-csi` | Installs the EBS CSI add-on and creates the configured gp3 StorageClass. |
| EFS CSI | `03-live/clients/client-a/dev/06-efs-csi` | Creates or adopts EFS, then installs the EFS CSI add-on and creates the configured RWX StorageClass. |
| Monitoring | `03-live/clients/client-a/dev/07-monitoring` | Installs the Prometheus, Grafana, and Alertmanager Helm release after EBS storage is available. |
| Logging | `03-live/clients/client-a/dev/08-logging` | Installs Loki and Grafana Alloy in the existing monitoring namespace, then provisions the Loki datasource and Kubernetes Logs dashboard in Grafana. |

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

Then deploy the bastion, followed by EKS:

```bash
cd ../03-bastion
terragrunt init
terragrunt validate
terragrunt plan
terragrunt apply
```

```bash
cd ../04-eks

```bash
cd ../04-eks
terragrunt init
terragrunt validate
terragrunt plan
terragrunt apply
```

Then deploy the EBS CSI add-on and StorageClass:

```bash
cd ../05-ebs-csi
terragrunt init
terragrunt validate
terragrunt plan
terragrunt apply
```

Then deploy EFS storage:

```bash
cd ../06-efs-csi
terragrunt init
terragrunt validate
terragrunt plan
terragrunt apply
```

Then deploy the monitoring Helm release through Terraform:

```bash
cd ../07-monitoring
terragrunt init
terragrunt validate
terragrunt plan
terragrunt apply
```

Then deploy logging:

```bash
cd ../08-logging
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

## Use EBS persistent storage

After the `05-ebs-csi` component has been applied, verify the controller and StorageClass:

```bash
kubectl get pods -n kube-system -l app=ebs-csi-controller
kubectl get storageclass ebs-gp3
```

Create a dynamically provisioned EBS-backed claim with the included example:

```bash
kubectl apply -f 13-kubernetes-apps/ebs-pvc-example.yaml
kubectl get pvc app-data
```

EBS volumes support `ReadWriteOnce`, so use one PVC per replica for workloads that run on multiple nodes. `WaitForFirstConsumer` delays volume creation until the pod is scheduled, ensuring the volume is created in that pod's Availability Zone. Set `ebs.reclaim_policy` to `Retain` in the environment YAML when deleting a claim must preserve its EBS volume.

To use a volume that already exists, set `ebs.create: false` and provide its `ebs.existing_id` (for example, `vol-0123456789abcdef0`). The component discovers the volume's size and Availability Zone, then creates a static PV and an `existing-ebs-pvc` claim in the configured namespace. The volume is retained if the Terragrunt component is destroyed.

## Use EFS persistent storage

The `efs-sc` StorageClass dynamically creates an EFS access point for each claim and supports `ReadWriteMany`. Apply the included example:

```bash
kubectl apply -f 13-kubernetes-apps/efs-pvc-example.yaml
kubectl get pvc shared-app-data
```

For a new EFS file system, set `efs.create: true`; mount targets and their NFS security group are created in every private subnet. To adopt an existing file system, set `efs.create: false` and `efs.existing_id` to its `fs-...` ID. Existing EFS mount targets must already be reachable from the EKS node security group over TCP port 2049.

## Deploy the sample Helm chart

After installing the required controllers and setting a real EFS file-system ID in `13-kubernetes-apps/test-app/values.yaml`:

```bash
helm upgrade --install eks-test-app ./13-kubernetes-apps/test-app
kubectl get pods,svc,ingress,pv,pvc
```

## Deploy monitoring

The `07-monitoring` Terragrunt component manages the pinned `prometheus-community/kube-prometheus-stack` Helm release in the `monitoring` namespace. It depends on `05-ebs-csi` and configures Prometheus, Grafana, and Alertmanager with EBS-backed claims.

```bash
./scripts/deploy-env.sh client-a dev
```

Grafana receives the chart's built-in Kubernetes dashboards, including cluster, node, namespace, and pod CPU/memory, network, and resource views. To access Grafana locally:

```bash
kubectl -n monitoring port-forward svc/monitoring-grafana 3000:80
kubectl -n monitoring get secret monitoring-grafana -o jsonpath='{.data.admin-password}' | base64 --decode; echo
```

Use `admin` as the Grafana user. Configure Alertmanager receivers (for email, Slack, PagerDuty, or another destination) in the `monitoring` section of the client override file before relying on notifications.

## Deploy logging

The `08-logging` Terragrunt component deploys Loki and Grafana Alloy into the existing `monitoring` namespace. Alloy collects pod logs from all namespaces and Kubernetes events through the Kubernetes API and sends them to Loki. The Grafana sidecars installed by `07-monitoring` automatically discover the managed Loki datasource and **Kubernetes Logs** dashboard.

Monitoring, Loki, and Alloy values share one client-owned override file. Its path is explicitly configured in the environment YAML:

```yaml
monitoring:
  override_values_file: "clients/client-a/monitoring-and-logging/override.yaml"

logging:
  override_values_file: "clients/client-a/monitoring-and-logging/override.yaml"
```

For `client-a`, edit [the shared override](/home/vedant-bari/workspace/nuclesteq/terraform-eks-cookiecutter/12-platform-config/clients/client-a/monitoring-and-logging/override.yaml). The modules select their respective `monitoring`, `loki`, or `alloy` section before passing it to Helm. The committed Loki configuration is a persistent single-replica filesystem deployment for development; use an S3-backed distributed configuration before relying on it for highly available production log retention.

## Destroy

The destroy helper is interactive:

```bash
./scripts/destroy-env.sh client-a dev
```

It destroys EKS, then bastion, then VPC, then bootstrap. Destroying bootstrap deletes the Terraform state bucket and KMS key; use this only when permanently removing the environment.

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

The VPC, bastion, and EKS stacks are implemented. VPC flow logs/endpoints, private EKS endpoint access, subnet discovery tags, IAM/IRSA configuration, and the Helm chart's AWS dependencies are future work needed for a production-ready platform.
