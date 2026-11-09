# Terraform + Terragrunt AWS EKS platform

This folder contains the AWS EKS implementation of the multi-cloud platform blueprint. The active structure and operating model now follow the recently merged GKE implementation: YAML-driven client/environment configuration, reusable Terraform modules, Terragrunt live layers, stable remote-state keys, dependency-driven outputs, plan/apply separation, guarded destroy, static validation, and runbooks.

The current reference environment is AMEX dev. Treat it as a starting configuration: verify AWS account, region, EKS version, network ranges, sizing, and costs before using it.

## Architecture and runbooks

- [AWS EKS architecture](00-documentation/architecture/AWS_EKS_ARCHITECTURE.md)
- [Deployment and teardown runbook](00-documentation/deployment/AWS_EKS_DEPLOYMENT_RUNBOOK.md)
- [Legacy-to-stable state migration guidance](00-documentation/deployment/STATE_LAYOUT_MIGRATION.md)

## Active repository layout

```text
aws-eks/
├── 00-documentation/
├── 01-config/clients/<client>/<environment>/
├── 02-scripts/
│   ├── bootstrap/
│   ├── scaffolding/
│   └── templates/
├── 03-modules/
├── 04-live/
├── 05-helm-charts/generic-app/
├── 06-examples/storage/
└── 07-tests/
```

The previous 01-bootstrap, 03-live, 12-platform-config, 13-kubernetes-apps, and 15-scripts directories are retained as legacy material for reference. New automation must use the active paths above. Do not mix old and new live roots for the same infrastructure.

## Platform components

| Layer | Function |
| --- | --- |
| 01-network | Create a VPC or adopt an existing VPC and supplied subnet IDs; VPC Flow Logs are enabled for newly created VPCs |
| 02-bastion | Optional EC2 administration host; SSM-first IAM profile, no default ingress |
| 03-eks | EKS control plane, managed node groups, private API endpoint, OIDC/IRSA, control-plane logs |
| 04-ebs-csi | EBS CSI managed add-on, IRSA, encrypted gp3 StorageClass, optional static PV/PVC for an existing volume |
| 05-efs-csi | EFS CSI managed add-on, IRSA, optional encrypted EFS and mount targets, RWX StorageClass |
| 06-monitoring | kube-prometheus-stack Helm release |
| 07-logging | Loki and Alloy Helm releases plus Grafana datasource/dashboard integration |
| 08-applications | YAML-driven Helm releases using the shared generic application chart |

The sample config uses three AZs, one NAT Gateway for development cost control, a private-only EKS API endpoint, two managed node groups, EBS/EFS CSI, Prometheus/Grafana, Loki/Alloy, and an optional application release. Review the trade-offs before adopting the sample for production.

## Terraform and Terragrunt conventions

- Terraform modules are self-contained and declare required providers/version constraints.
- Client/environment-specific values are supplied through YAML; modules do not hardcode account IDs, client names, or environment-specific CIDRs.
- The live root loads the YAML config, generates the AWS provider with default tags, and configures the S3 backend.
- State keys use stable logical layer names: aws-eks/<client>/<environment>/<logical-layer>/terraform.tfstate.
- Live units consume upstream dependency outputs. Mock outputs are restricted to init and validate; never plan with mock values.
- Bootstrap/state storage is created before live-layer initialization and is excluded from normal deploy/destroy orchestration.
- Plan generation, apply, and destroy are separate commands. Saved plans are private, bound to branch/commit, and SHA-256 checked before use.
- Destroy is plan-only by default, supports a single layer, and requires --destroy plus typed confirmation to execute.
- Tests are read-only: they check YAML, module references, dependency paths, state-key mapping, Python/Bash syntax, and Helm lint/render when Helm is installed.

## Quick start

Check out the feature branch and review the configuration:

```bash
git fetch origin
git switch feature/aws-eks-gke-parity
git pull --ff-only origin feature/aws-eks-gke-parity
```

Review:
- aws-eks/01-config/clients/amex/dev/infra/dev.yaml
- aws-eks/01-config/clients/amex/dev/monitoring-and-logging/override.yaml

Required tools are Terraform 1.15.x, Terragrunt 1.1.x, AWS CLI v2, Python 3 with PyYAML, kubectl, and Helm. Check AWS identity:

```bash
aws sts get-caller-identity
```

For a new client/environment, first add its YAML configuration, then generate the eight Terragrunt live units:

```bash
python3 aws-eks/02-scripts/scaffolding/scaffold_client.py --client <client> --environment <environment>
```

Existing live HCL is preserved unless --force is explicitly supplied. Review generated files before running any plan.

If the configured S3 state bucket does not exist, review its globally unique name and create it:

```bash
bash aws-eks/02-scripts/bootstrap/create-state-bucket.sh aws-tf-state-amex-dev ap-south-1
```

Run read-only checks:

```bash
bash aws-eks/07-tests/run_tests.sh
```

Deploy by planning, reviewing, and applying one layer at a time. For a fresh environment, do not plan every layer before applying the first one because downstream layers require real upstream state outputs. The complete command sequence and teardown process are in the deployment runbook.

## Security and operational constraints

- The sample EKS endpoint is private-only. Run Terraform/Kubernetes/Helm operations from a network that can reach the EKS private endpoint.
- If public endpoint access is enabled, the module requires an explicit CIDR allowlist.
- Bastion is disabled by default. If enabled, it has no default inbound rules; its sample public-subnet placement uses a public IP for outbound SSM connectivity. For a private-only bastion, provision SSM interface endpoints first.
- The state bucket uses S3 versioning, SSE-S3 encryption, public-access blocks, and a deny-insecure-transport policy. This bootstrap script does not create a customer-managed KMS key.
- Saved plan files and state can contain sensitive values. Keep them outside Git with restrictive permissions.
- Do not destroy the S3 backend bucket as part of an environment teardown.
- Existing infrastructure deployed with the legacy 03-live root needs state migration before using the new 04-live root. Follow STATE_LAYOUT_MIGRATION.md; never apply a plan that proposes recreating existing resources.

## Known gaps before production use

This branch does not currently provision ECR repositories/image lifecycle, Jenkins CI/CD, AWS Secrets Manager-to-External-Secrets integration, AWS Load Balancer Controller, Karpenter, or VPC interface endpoints. The generic application chart can configure ALB ingress and external-secret references, but those integrations must remain disabled until their controllers and IAM are installed and tested.

The sample Loki deployment is a single replica using filesystem storage. It is not a highly available or durable production logging architecture. Production adoption also requires HA sizing, S3-backed Loki storage, alert routing, retention review, disaster-recovery design, and cost/security validation.

No AWS infrastructure is created, modified, or destroyed by the repository edits in this branch.
