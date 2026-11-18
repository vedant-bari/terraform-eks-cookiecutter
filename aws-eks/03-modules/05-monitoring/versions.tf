terraform {
  required_version = ">= 1.15.0"

  required_providers {
    # Not used directly; root.hcl generates an aws provider block for every unit.
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 3.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 3.0"
    }
  }
}
