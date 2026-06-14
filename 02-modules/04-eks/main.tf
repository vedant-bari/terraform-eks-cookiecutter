terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.0"
    }
  }
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.0"

  #################################################
  # Cluster Configuration
  #################################################

  name               = var.cluster_name
  kubernetes_version = var.kubernetes_version

  #################################################
  # Networking
  #################################################

  vpc_id     = var.vpc_id
  subnet_ids = var.private_subnet_ids

  #################################################
  # IAM
  #################################################

  create_iam_role = false
  iam_role_arn    = var.cluster_role_arn

  #################################################
  # Security Groups
  #################################################

  create_security_group = true
  create_node_security_group    = true

  #################################################
  # OIDC
  #################################################

  enable_irsa = true

  #################################################
  # Endpoint Access
  #################################################

  endpoint_public_access  = var.endpoint_public_access
  endpoint_private_access = var.endpoint_private_access

  endpoint_public_access_cidrs = var.public_access_cidrs

  #################################################
  # Cluster Logging
  #################################################

  enabled_log_types = var.enabled_cluster_log_types

  #################################################
  # Encryption
  #################################################

  encryption_config = {
    resources = ["secrets"]
  }

  #################################################
  # AWS Managed Add-ons
  #################################################

  addons = {
    coredns = {
      resolve_conflicts_on_create = "OVERWRITE"
      resolve_conflicts_on_update = "OVERWRITE"
    }

    kube-proxy = {
      resolve_conflicts_on_create = "OVERWRITE"
      resolve_conflicts_on_update = "OVERWRITE"
    }

    vpc-cni = {
      resolve_conflicts_on_create = "OVERWRITE"
      resolve_conflicts_on_update = "OVERWRITE"
    }

    aws-ebs-csi-driver = {
      resolve_conflicts_on_create = "OVERWRITE"
      resolve_conflicts_on_update = "OVERWRITE"
    }
  }

  #################################################
  # EKS Managed Node Groups
  #################################################

  eks_managed_node_groups = {

    #################################################
    # System Node Group
    #################################################

    system = {
      name = "${var.cluster_name}-system"

      iam_role_arn = var.node_role_arn

      ami_type = "BOTTLEROCKET_x86_64"

      instance_types = var.system_node_group.instance_types

      min_size     = var.system_node_group.min_size
      max_size     = var.system_node_group.max_size
      desired_size = var.system_node_group.desired_size

      subnet_ids = var.private_subnet_ids

      capacity_type = var.system_node_group.capacity_type

      labels = {
        workload = "system"
      }

      taints = {
        system = {
          key    = "CriticalAddonsOnly"
          value  = "true"
          effect = "NO_SCHEDULE"
        }
      }

      tags = merge(
        var.tags,
        {
          Name = "${var.cluster_name}-system-ng"
        }
      )
    }

    #################################################
    # Application Node Group
    #################################################

    application = {
      name = "${var.cluster_name}-application"

      iam_role_arn = var.node_role_arn

      ami_type = "BOTTLEROCKET_x86_64"

      instance_types = var.application_node_group.instance_types

      min_size     = var.application_node_group.min_size
      max_size     = var.application_node_group.max_size
      desired_size = var.application_node_group.desired_size

      subnet_ids = var.private_subnet_ids

      capacity_type = var.application_node_group.capacity_type

      labels = {
        workload = "application"
      }

      tags = merge(
        var.tags,
        {
          Name = "${var.cluster_name}-application-ng"
        }
      )
    }
  }

  #################################################
  # Tags
  #################################################

  tags = merge(
    var.tags,
    {
      Environment = var.environment
      ManagedBy   = "Terraform"
      Terraform   = "true"
    }
  )
}