terraform {
  required_version = ">= 1.0.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.0"
    }
  }
# Remote Backend
  backend "s3" {
    bucket         = var.s3_bucket_name
    key            = var.s3_bucket_key
    region         = var.aws_region
    encrypt        = true
    use_lockfile   = true
  }   
}

provider "aws" {
  region = var.aws_region
}