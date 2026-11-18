output "cluster_name" {
  description = "EKS cluster name."
  value       = module.eks.cluster_name
}

output "cluster_arn" {
  description = "EKS cluster ARN."
  value       = module.eks.cluster_arn
}

output "cluster_endpoint" {
  description = "Kubernetes API endpoint (https://...)."
  value       = module.eks.cluster_endpoint
}

output "cluster_certificate_authority_data" {
  description = "Base64-encoded cluster CA certificate."
  value       = module.eks.cluster_certificate_authority_data
}

output "kubernetes_version" {
  description = "Kubernetes minor version of the control plane."
  value       = module.eks.cluster_version
}

output "cluster_security_group_id" {
  description = "Additional cluster security group created by the module."
  value       = module.eks.cluster_security_group_id
}

output "cluster_primary_security_group_id" {
  description = "EKS-created primary cluster security group (attached to nodes and control-plane ENIs)."
  value       = module.eks.cluster_primary_security_group_id
}

output "node_security_group_id" {
  description = "Node security group; 04-storage allows NFS from it to EFS."
  value       = module.eks.node_security_group_id
}

output "node_iam_role_arns" {
  description = "Node IAM role ARN for each managed node group."
  value       = { for k, v in module.eks.eks_managed_node_groups : k => v.iam_role_arn }
}

output "node_group_autoscaling_group_names" {
  description = "ASG names behind the managed node groups (Cluster Autoscaler discovers them by tag)."
  value       = module.eks.eks_managed_node_groups_autoscaling_group_names
}

output "kms_key_arn" {
  description = "KMS key encrypting Kubernetes secrets."
  value       = module.eks.kms_key_arn
}

output "oidc_provider_arn" {
  description = "IAM OIDC provider ARN, or null when enable_irsa is false."
  value       = var.enable_irsa ? module.eks.oidc_provider_arn : null
}

output "service_ipv4_cidr" {
  description = "Kubernetes service CIDR."
  value       = var.service_ipv4_cidr
}

output "addon_pod_identity_role_arns" {
  description = "Pod Identity role ARN for each AWS-owned add-on."
  value       = { for k, v in aws_iam_role.pod_identity : k => v.arn }
}
