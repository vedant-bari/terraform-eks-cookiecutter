terraform {
  required_version = ">= 1.8.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  backend "s3" {
    bucket         = "${var.project_name}-${var.environment}-terraform-bucket"
    key            = "eks/${var.project_name}-${var.environment}/terraform.tfstate"
    region         = local.config.project.region
    dynamodb_table =  "${var.project_name}-${var.environment}-dynamodb-table"
    encrypt        = true
    
  }
}

provider "aws" {
  region = local.config.project.region

  default_tags {
    tags = {
      Project     = local.config.project.name
      Environment = local.config.project.environment
      ManagedBy   = "Terraform"
    }
  }
}