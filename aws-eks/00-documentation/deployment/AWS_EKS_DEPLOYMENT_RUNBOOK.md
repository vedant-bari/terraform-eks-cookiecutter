# AWS EKS deployment runbook

## Scope

The active Terragrunt environment added in this branch is AMEX dev. It is a reference environment, not a production approval. Review account, region, CIDRs, EKS version, instance sizing, and costs before use.

Active configuration:
- Infrastructure: aws-eks/01-config/clients/amex/dev/infra/dev.yaml
- Monitoring/logging values: aws-eks/01-config/clients/amex/dev/monitoring-and-logging/override.yaml
- Sample app values: aws-eks/01-config/clients/amex/dev/applications/nginx.yaml

## 1. Check out the implementation branch

From the repository root:

```bash
git fetch origin
git switch feature/aws-eks-gke-parity
git pull --ff-only origin feature/aws-eks-gke-parity
git status --short --branch
```

Do not run deployment scripts from a dirty working tree. The plan/apply scripts bind saved plans to the current branch and commit.

## 2. Prerequisites and identity

Required tooling:
- Terraform 1.15.x
- Terragrunt 1.1.x
- AWS CLI v2
- Python 3 and PyYAML
- kubectl and Helm

Check the active AWS identity and region:

```bash
aws sts get-caller-identity
aws configure get region
```

The AWS account returned by STS is recorded in the plan manifest and must match at apply/destroy time. The region used by Terraform is taken from the environment YAML, not inferred from the shell's default region.

The sample EKS API endpoint is private-only. Run Terraform from a host that can reach the cluster private endpoint (for example, a VPC-connected runner or VPN). This is required not only for kubectl, but also for the EBS/EFS CSI, Helm, monitoring, logging, and application layers.

## 3. Review configuration

Before creating anything, review the active YAML. In particular:

- Confirm aws.region and bootstrap.state_bucket_name.
- Confirm the S3 bucket name is globally unique and belongs to the intended AWS account.
- Confirm VPC CIDRs do not overlap with connected networks.
- Confirm all configured Availability Zones exist in the selected region.
- Confirm cluster_version is currently supported in the target region.
- Review node group instance types, desired/min/max sizes, and Spot use.
- Keep endpoint_public_access false unless public access is required; if enabled, set a narrow CIDR allowlist.
- Bastion is disabled by default. If enabling it, review every ingress rule and keep SSH restricted to trusted source CIDRs. The sample public-subnet bastion uses a public IP only for outbound SSM connectivity; it has no default inbound rules. A private-only bastion requires SSM interface endpoints, which are not provisioned by this stack.
- Review NAT Gateway cost and the single-NAT availability trade-off.
- Review EBS/EFS reclaim policies and storage retention.
- Review monitoring resource requests, storage sizes, and chart versions.
- Applications are disabled by default. The NGINX values file is a sample only.

Do not put passwords, tokens, private keys, or other secrets in YAML or Git.

### Scaffold another client/environment

For a new client or environment, create and review its infrastructure YAML and any monitoring/logging or application values first. Preview the live-unit generation:

```bash
python3 aws-eks/02-scripts/scaffolding/scaffold_client.py \
  --client <client> \
  --environment <environment> \
  --dry-run
```

Then generate the eight standard Terragrunt live units:

```bash
python3 aws-eks/02-scripts/scaffolding/scaffold_client.py \
  --client <client> \
  --environment <environment>
```

The scaffolder preserves existing files by default. Review every generated HCL file and dependency path. Do not use --force unless you intend to replace customized live configuration.

## 4. Create the remote-state bucket

The S3 backend bucket must exist before Terragrunt can initialize any live layer. The bootstrap bucket is outside the environment lifecycle.

If the bucket does not already exist and you have confirmed the configured name is available:

```bash
bash aws-eks/02-scripts/bootstrap/create-state-bucket.sh aws-tf-state-amex-dev ap-south-1
```

The script prompts for the word create and configures versioning, SSE-S3 encryption, S3 public-access blocks, and a bucket policy denying insecure transport. It does not create or migrate Terraform state.

If the environment already has state, do not create a new bucket or change the configured bucket name without first following the state migration guidance. Never delete the backend bucket during environment teardown.

## 5. Run read-only validation

```bash
bash aws-eks/07-tests/run_tests.sh
```

This checks YAML parsing and duplicate keys, module/live wiring, dependency paths, stable state-key mappings, Python/Bash syntax, and (when Helm is installed) chart lint/rendering. It does not initialize Terraform, contact AWS, or create infrastructure.

## 6. Plan and apply one layer at a time

Layer order:

1. 01-network
2. 02-bastion (optional)
3. 03-eks
4. 04-ebs-csi
5. 05-efs-csi
6. 06-monitoring
7. 07-logging
8. 08-applications (disabled unless explicitly enabled)

For a new environment, do not generate all eight plans at once. Downstream layers consume real upstream state outputs, and mock outputs are deliberately restricted to init/validate. Plan, review, and apply each layer before planning the next.

Example for the network layer:

```bash
LAYER=01-network
PLAN_DIR=$(mktemp -d /tmp/amex-dev-network.XXXXXX)
chmod 700 "$PLAN_DIR"

bash aws-eks/02-scripts/plan-env.sh amex dev \
  --layer "$LAYER" \
  --plan-dir "$PLAN_DIR"
```

Review the exact saved plan:

```bash
terragrunt --working-dir \
  aws-eks/04-live/clients/amex/dev/$LAYER \
  run -- show -no-color "$PLAN_DIR/$LAYER.tfplan"
```

If the plan is correct, apply that exact saved plan:

```bash
bash aws-eks/02-scripts/apply-env.sh amex dev \
  --plan-dir "$PLAN_DIR" \
  --approve
```

The script validates branch, commit, working tree, AWS account, and SHA-256 checksums, then displays each plan again and requires typing yes. The --approve flag alone does not bypass the typed confirmation.

Repeat with a new empty plan directory for each subsequent layer. Inspect each plan before proceeding. If a layer fails after earlier layers succeeded, those earlier resources remain deployed; fix the failure and continue from the first unapplied layer.

The deploy-env.sh entrypoint is intentionally plan-only and delegates to plan-env.sh. It never applies infrastructure.

## 7. Read outputs and verify services

Read outputs per live layer:

```bash
terragrunt --working-dir aws-eks/04-live/clients/amex/dev/03-eks run -- output
terragrunt --working-dir aws-eks/04-live/clients/amex/dev/04-ebs-csi run -- output
terragrunt --working-dir aws-eks/04-live/clients/amex/dev/05-efs-csi run -- output
```

Update kubeconfig after the EKS cluster exists:

```bash
aws eks update-kubeconfig --region ap-south-1 --name eks-amex-dev
kubectl get nodes
kubectl get pods -n kube-system
kubectl get storageclass
kubectl get pods -n monitoring
```

Because the cluster endpoint is private, these commands must run from a network with access to the EKS VPC.

Grafana can be accessed through port-forwarding:

```bash
kubectl -n monitoring port-forward svc/monitoring-grafana 3000:80
```

Use the chart-generated Grafana secret to retrieve the password locally. Do not paste it into chat or commit it.

## 8. Enable sample applications

The sample application is not deployed by default. To enable it, set applications.enabled to true in the infrastructure YAML, review the application values under the applications directory, commit the reviewed configuration, and then plan/apply only 08-applications.

The generic chart supports ALB ingress and optional external-secret integration, but this repository does not currently install AWS Load Balancer Controller or External Secrets Operator/ClusterSecretStore. Keep ingress and externalSecret disabled unless those platform prerequisites are independently installed and verified.

## 9. Destroy one layer only

To create a destroy plan for just the network layer:

```bash
DESTROY_PLAN_DIR=$(mktemp -d /tmp/amex-dev-network-destroy.XXXXXX)
chmod 700 "$DESTROY_PLAN_DIR"

bash aws-eks/02-scripts/destroy-env.sh amex dev \
  --layer 01-network \
  --plan-dir "$DESTROY_PLAN_DIR"
```

Review it:

```bash
terragrunt --working-dir aws-eks/04-live/clients/amex/dev/01-network \
  run -- show -no-color "$DESTROY_PLAN_DIR/01-network.tfplan"
```

Only if downstream components have already been removed and the plan is correct:

```bash
bash aws-eks/02-scripts/destroy-env.sh amex dev \
  --destroy \
  --layer 01-network \
  --plan-dir "$DESTROY_PLAN_DIR"
```

The script requires typing destroy. Destroying the network while EKS, load balancers, mount targets, NAT gateways, or other attached resources remain will fail or leave the environment inconsistent. Destroy dependent components first.

## 10. Destroy the full environment

The helper creates destroy plans only by default, in reverse dependency order:

```bash
DESTROY_PLAN_DIR=$(mktemp -d /tmp/amex-dev-destroy.XXXXXX)
chmod 700 "$DESTROY_PLAN_DIR"

bash aws-eks/02-scripts/destroy-env.sh amex dev \
  --plan-dir "$DESTROY_PLAN_DIR"
```

Review all plans in this order:

```bash
for LAYER in 08-applications 07-logging 06-monitoring 05-efs-csi 04-ebs-csi 03-eks 02-bastion 01-network; do
  echo "===== $LAYER ====="
  terragrunt --working-dir "aws-eks/04-live/clients/amex/dev/$LAYER" \
    run -- show -no-color "$DESTROY_PLAN_DIR/$LAYER.tfplan"
done
```

Execute only after reviewing every plan:

```bash
bash aws-eks/02-scripts/destroy-env.sh amex dev \
  --destroy \
  --plan-dir "$DESTROY_PLAN_DIR"
```

The script validates the manifest, branch, commit, AWS account, reverse dependency order, and plan checksums. It prompts for destroy for each layer. The S3 state bucket is never included.

## 11. State migration warning

The legacy AWS live root under 03-live used path-relative S3 state keys. The new 04-live root uses stable logical keys under aws-eks/<client>/<environment>/<layer>. These are different backend keys.

If any AWS resources were previously created from the legacy tree, do not run plans against the new tree until state has been backed up and migrated. See STATE_LAYOUT_MIGRATION.md. A fresh plan against an empty new key can propose duplicate resources even though the infrastructure already exists.

## 12. Operational limitations

- The sample config uses one NAT Gateway to reduce dev cost; this is not AZ-resilient.
- EKS API access is private-only by default.
- The bastion is disabled by default and has no default SSH ingress.
- VPC Flow Logs are enabled for newly created VPCs; interface VPC endpoints are not yet wired.
- EBS/EFS CSI add-ons use IRSA.
- Loki is configured as a single-replica filesystem-backed development deployment, not an HA production logging service.
- ECR repository lifecycle and Jenkins CI/CD are not provisioned by these layers; the sample app pulls from a public image registry.
- AWS Secrets Manager integration, External Secrets Operator/ClusterSecretStore, AWS Load Balancer Controller, Karpenter, VPC interface endpoints, and production S3-backed Loki are not provisioned by these layers.
