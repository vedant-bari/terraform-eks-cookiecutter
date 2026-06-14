#!/bin/bash
set -e

echo "==============================="
echo "STEP-1: Create VPC using Terraform"
echo "==============================="
cd 01-vpc
terraform init 
terraform apply -auto-approve

echo
echo "==============================="
echo "STEP-2: Create EKS Cluster using Terraform"
echo "==============================="
cd ../02-eks
terraform init 
terraform apply -auto-approve

echo
echo "✅ EKS Cluster and VPC creation completed successfully!"