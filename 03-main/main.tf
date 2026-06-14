module "vpc" {
  source = "../02-modules/vpc"

  name               = var.environment
  cidr_block         = var.vpc_cidr
  availability_zones = var.availability_zones
  public_subnets     = var.public_subnets
  private_subnets    = var.private_subnets
}

module "eks" {
  source = "../02-modules/eks"

  cluster_name       = var.cluster_name
  cluster_version    = var.cluster_version
  subnet_ids         = module.vpc.private_subnet_ids
  vpc_id             = module.vpc.vpc_id
  node_instance_type = var.node_instance_type
  desired_size       = var.desired_size
  min_size           = var.min_size
  max_size           = var.max_size
}



module "alb_controller" {
  source = "../02-modules/alb-controller"

  cluster_name = module.eks.cluster_name
}

module "external_dns" {
  source = "../02-modules/external-dns"

  cluster_name = module.eks.cluster_name
}

module "monitoring" {
  source = "../02-modules/monitoring"

  cluster_name = module.eks.cluster_name
}