# EKS cluster Terraform module

This module wraps terraform-aws-modules/eks/aws v21.x. It is consumed by the Terragrunt live unit under 04-live; deploy it through the saved-plan orchestration rather than running Terraform directly from this module directory.

## Responsibilities

- EKS managed control plane and managed node groups.
- Private/public API endpoint controls with explicit public CIDR allowlisting.
- OIDC provider and IRSA support.
- Cluster add-ons (CoreDNS, kube-proxy, VPC CNI).
- EKS control-plane log group and retention.
- Cluster creator access entry for the deploying identity.

## Inputs

| Input | Purpose |
| --- | --- |
| cluster_name | Logical cluster name; mapped to the v21 module's name input |
| cluster_version | Kubernetes minor version; mapped to kubernetes_version |
| vpc_id / private_subnet_ids | Network placement |
| cluster_endpoint_private_access | Private API endpoint toggle |
| cluster_endpoint_public_access | Public API endpoint toggle |
| cluster_endpoint_public_access_cidrs | Explicit CIDR allowlist; required if public access is enabled |
| cluster_addons | EKS add-on map; mapped to v21 addons |
| cluster_enabled_log_types | Control-plane log types; mapped to v21 enabled_log_types |
| create_cloudwatch_log_group | Whether the module creates the control-plane log group |
| cloudwatch_log_group_retention_in_days | Log retention |
| node_groups | EKS managed node group definitions |
| tags | Common resource tags |

## Outputs

- cluster_name
- cluster_endpoint
- cluster_certificate_authority_data
- cluster_oidc_issuer_url
- oidc_provider_arn
- node_security_group_id
- cluster_security_group_id

## Version compatibility

The v21 major release renamed several inputs from the v20 interface, including cluster_name to name, cluster_version to kubernetes_version, cluster_addons to addons, cluster_enabled_log_types to enabled_log_types, and cluster_endpoint_* to endpoint_*. The wrapper keeps stable local input names and maps them to the v21 API.

The current v21.29.x release line requires Terraform >=1.5.7 and AWS provider >=6.59. The repository constrains the AWS provider to the 6.x major line; Terraform will resolve a compatible 6.x provider satisfying both constraints. Review the upstream upgrade guide before changing the module major version:
https://github.com/terraform-aws-modules/terraform-aws-eks/blob/master/docs/UPGRADE-21.0.md

The upstream module currently exposes a separate KMS-backed secret encryption configuration. Review its defaults and key lifecycle before changing them.
