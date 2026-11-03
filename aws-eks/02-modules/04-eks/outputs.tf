# ==========================================
# Cluster Core Outputs
# ==========================================
output "cluster_name" {
  description = "The name of the EKS cluster"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "Endpoint for your Kubernetes API server"
  value       = module.eks.cluster_endpoint
}

output "cluster_version" {
  description = "The Kubernetes version for the cluster"
  value       = module.eks.cluster_version
}

output "cluster_arn" {
  description = "The Amazon Resource Name (ARN) of the cluster"
  value       = module.eks.cluster_arn
}

# ==========================================
# OIDC & IAM Outputs (Required for IRSA)
# ==========================================
output "oidc_provider_arn" {
  description = "The ARN of the OIDC Provider if enable_irsa = true"
  value       = module.eks.oidc_provider_arn
}

output "cluster_oidc_issuer_url" {
  description = "The URL on the EKS cluster for the OpenID Connect identity provider"
  value       = module.eks.cluster_oidc_issuer_url
}

# ==========================================
# Security Group Outputs
# ==========================================
output "cluster_security_group_id" {
  description = "Security group ID attached to the EKS cluster control plane"
  value       = module.eks.cluster_security_group_id
}

output "node_security_group_id" {
  description = "Security group ID attached to the EKS worker nodes"
  value       = module.eks.node_security_group_id
}

# ==========================================
# Network Pass-Through Outputs
# (Sourced from variables, not the EKS module)
# ==========================================
output "vpc_id" {
  description = "The ID of the VPC (Passed through from VPC component)"
  value       = var.vpc_id
}

output "subnet_ids" {
  description = "List of private subnet IDs (Passed through from VPC component)"
  value       = var.private_subnet_ids
}

# ==========================================
# Add-on Configurations
# ==========================================
output "alb_controller_configuration" {
  description = "ALB Ingress Controller configuration mapping for downstream use"
  value = {
    vpc_id            = var.vpc_id
    cluster_name      = module.eks.cluster_name
    cluster_endpoint  = module.eks.cluster_endpoint
    oidc_provider_arn = module.eks.oidc_provider_arn
  }
}