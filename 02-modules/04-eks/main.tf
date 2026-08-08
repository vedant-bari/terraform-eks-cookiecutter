module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version

  vpc_id     = var.vpc_id
  subnet_ids = var.private_subnet_ids

  cluster_endpoint_public_access = true
  enable_cluster_creator_admin_permissions = true

  cluster_addons = var.cluster_addons
  tags           = var.tags

  # Apply the logging variable
  cluster_enabled_log_types = var.cluster_enabled_log_types
  
  # NEW: Now dynamically driven by your YAML config
  create_cloudwatch_log_group = var.create_cloudwatch_log_group

  eks_managed_node_groups = var.node_groups
}