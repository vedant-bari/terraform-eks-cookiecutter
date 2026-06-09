# Environment & Region 
environment_name = "dev"
aws_region       = "us-east-1"

##s3bucket details
s3_bucket_name = "tfstate-dev-us-east-1-jpjtof"
s3_bucket_key  = "vpc/dev/terraform.tfstate"

# CIDR for VPC
vpc_cidr = "10.0.0.0/16"

# Subnet mask (/24 subnets)
subnet_newbits = 8

# Tags 
tags = {
  Terraform   = "true"
}