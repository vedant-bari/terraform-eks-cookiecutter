# EKS Node Role Module

## Purpose

This module creates the IAM role used by Amazon EKS worker nodes.

The role can be used by:

- EKS Managed Node Groups
- Self-managed Node Groups

## Resources Created

- IAM Role
- IAM Instance Profile
- Required AWS Managed Policy Attachments

## Attached Policies

| Policy | Purpose |
|----------|-----------|
| AmazonEKSWorkerNodePolicy | Allows worker nodes to communicate with the EKS control plane |
| AmazonEKS_CNI_Policy | Required by the Amazon VPC CNI plugin |
| AmazonEC2ContainerRegistryReadOnly | Allows pulling container images from Amazon ECR |

## Usage

```hcl
module "node_role" {
  source = "./modules/iam/node-role"

  role_name = "dev-eks-node-role"

  tags = {
    Environment = "dev"
    ManagedBy   = "Terraform"
  }
}
```

## Outputs

- node_role_arn
- node_role_name
- instance_profile_arn
- instance_profile_name

## Notes

Additional permissions required by workloads should be implemented using IRSA instead of attaching them to the node role.