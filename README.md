# Terraform EKS Cookiecutter

Update values primarily in:
- environments/dev/terraform.tfvars

Bootstrap backend first, then populate backend.hcl and run:
terraform init -backend-config=backend.hcl
