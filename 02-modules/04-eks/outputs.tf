#################################################
# Cluster Information
#################################################

output "cluster_name" {
  description = "EKS cluster name"

  value = module.eks.cluster_name
}

output "cluster_arn" {
  description = "EKS cluster ARN"

  value = module.eks.cluster_arn
}

output "cluster_id" {
  description = "EKS cluster ID"

  value = module.eks.cluster_id
}

output "cluster_version" {
  description = "EKS Kubernetes version"

  value = module.eks.cluster_version
}

#################################################
# Cluster Endpoint Information
#################################################

output "cluster_endpoint" {
  description = "Endpoint for the EKS Kubernetes API server"

  value = module.eks.cluster_endpoint
}

output "cluster_certificate_authority_data" {
  description = "Base64 encoded certificate data required to communicate with the cluster"

  value     = module.eks.cluster_certificate_authority_data
  sensitive = true
}

#################################################
# OIDC / IRSA Outputs
#################################################

output "oidc_provider_arn" {
  description = "OIDC provider ARN used for IRSA"

  value = module.eks.oidc_provider_arn
}

output "oidc_provider" {
  description = "OIDC provider identifier"

  value = module.eks.oidc_provider
}

output "oidc_provider_url" {
  description = "OIDC issuer URL"

  value = module.eks.cluster_oidc_issuer_url
}

#################################################
# Security Group Outputs
#################################################

output "cluster_security_group_id" {
  description = "Cluster security group ID"

  value = module.eks.cluster_security_group_id
}

output "node_security_group_id" {
  description = "Node security group ID"

  value = module.eks.node_security_group_id
}

#################################################
# Managed Node Group Outputs
#################################################

output "eks_managed_node_groups" {
  description = "All managed node group information"

  value = module.eks.eks_managed_node_groups
}

output "managed_node_group_names" {
  description = "Managed node group names"

  value = keys(module.eks.eks_managed_node_groups)
}

output "managed_node_group_arns" {
  description = "Managed node group ARNs"

  value = {
    for k, v in module.eks.eks_managed_node_groups :
    k => v.node_group_arn
  }
}

#################################################
# Networking Outputs
#################################################

output "vpc_id" {
  description = "VPC ID used by the cluster"

  value = module.eks.vpc_id
}

output "subnet_ids" {
  description = "Subnet IDs associated with the cluster"

  value = module.eks.subnet_ids
}

#################################################
# EKS Add-on Outputs
#################################################

output "cluster_addons" {
  description = "AWS managed EKS add-ons"

  value = module.eks.cluster_addons
}

#################################################
# Authentication Outputs
#################################################

output "cluster_primary_security_group_id" {
  description = "Cluster primary security group ID"

  value = module.eks.cluster_primary_security_group_id
}

#################################################
# kubectl Configuration Outputs
#################################################

output "kubectl_config" {
  description = "kubectl configuration details"

  sensitive = true

  value = {
    cluster_name = module.eks.cluster_name
    endpoint     = module.eks.cluster_endpoint
    certificate  = module.eks.cluster_certificate_authority_data
  }
}

#################################################
# Useful Outputs for Downstream Modules
#################################################

output "irsa_configuration" {
  description = "IRSA configuration required by downstream modules"

  value = {
    oidc_provider_arn = module.eks.oidc_provider_arn
    oidc_provider_url = module.eks.cluster_oidc_issuer_url
  }
}

output "alb_controller_configuration" {
  description = "Configuration required by AWS Load Balancer Controller"

  value = {
    cluster_name             = module.eks.cluster_name
    oidc_provider_arn        = module.eks.oidc_provider_arn
    cluster_security_group_id = module.eks.cluster_security_group_id
    vpc_id                   = module.eks.vpc_id
  }
}

output "karpenter_configuration" {
  description = "Configuration required by Karpenter"

  value = {
    cluster_name      = module.eks.cluster_name
    cluster_endpoint  = module.eks.cluster_endpoint
    cluster_arn       = module.eks.cluster_arn
    oidc_provider_arn = module.eks.oidc_provider_arn
    node_security_group_id = module.eks.node_security_group_id
  }
}