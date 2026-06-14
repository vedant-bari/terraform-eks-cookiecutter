locals {
  environment = "dev"

  #################################################
  # Remote State Backend
  #################################################

  backend = {
    bucket = "company-dev-tf-state"
    key    = "dev"
    region = "us-east-1"
  }

  #################################################
  # Execution Role (Terragrunt / Terraform)
  #################################################

  execution_role_arn = "arn:aws:iam::111111111111:role/TerraformExecutionRole"

  #################################################
  # VPC Configuration
  #################################################

  vpc = {
    name = "vpc-dev"

    cidr = "10.0.0.0/16"

    azs = [
      "us-east-1a",
      "us-east-1b"
    ]

    private_subnets = [
      "10.0.1.0/24",
      "10.0.2.0/24"
    ]

    public_subnets = [
      "10.0.101.0/24",
      "10.0.102.0/24"
    ]

    database_subnets = [
      "10.0.151.0/24",
      "10.0.152.0/24"
    ]
  }

  #################################################
  # IAM Configuration
  #################################################

  iam = {
    cluster_role_name = "dev-eks-cluster-role"
    node_role_name    = "dev-eks-node-role"
  }

  #################################################
  # 🚀 EKS Configuration 
  #################################################

  eks = {

    #################################################
    # Cluster Basics
    #################################################

    cluster_name       = "dev-eks-cluster"
    kubernetes_version = "1.29"

    #################################################
    # Endpoint Access
    #################################################

    endpoint_public_access  = true
    endpoint_private_access = true

    # Restrict this in prod (VERY IMPORTANT)
    public_access_cidrs = ["0.0.0.0/0"]

    #################################################
    # Cluster Logging
    #################################################

    enabled_cluster_log_types = [
      "api",
      "audit",
      "authenticator",
      "controllerManager",
      "scheduler"
    ]

    #################################################
    # Node Groups Configuration
    #################################################

    node_groups = {

      system = {
        instance_types = ["t3.medium"]

        min_size     = 1
        max_size     = 2
        desired_size = 1

        capacity_type = "ON_DEMAND"
      }

      application = {
        instance_types = ["t3.large"]

        min_size     = 2
        max_size     = 5
        desired_size = 2

        capacity_type = "ON_DEMAND"
      }
    }
  }

  #################################################
  # Global Tags
  #################################################

  tags = {
    Environment = "dev"
    Project     = "platform-engineering"
    ManagedBy   = "terragrunt"
  }
}