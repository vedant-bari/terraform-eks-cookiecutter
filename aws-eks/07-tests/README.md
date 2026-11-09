# AWS EKS repository validation

Run from the repository root:

```bash
bash aws-eks/07-tests/run_tests.sh
```

The validator is read-only. It checks:

- YAML syntax and duplicate keys across client config, examples, and Helm defaults.
- AMEX dev configuration contracts, including subnet/AZ counts, endpoint exposure, bastion defaults, and opt-in application deployment.
- EKS Terraform module v21 input-name mapping.
- Standard module files and unique Terraform resource addresses.
- Stable logical S3 backend layer mapping.
- Live-unit module sources, dependency paths, root discovery, and template/live-unit parity.
- Mock-output restrictions (init/validate only).
- Monitoring/logging StorageClass and namespace placeholder wiring.
- Generic Helm chart safe defaults and duplicate PDB regression.
- Plan/apply/destroy orchestration invariants, saved-plan checksums, typed confirmation, and legacy wrapper delegation.
- Python syntax and Bash syntax.
- Helm lint and sample rendering when Helm is installed.

It does not run Terraform init/plan/apply/destroy, connect to AWS, or create cloud resources. A passing static check is not a substitute for reviewing a real plan in the target AWS account.
