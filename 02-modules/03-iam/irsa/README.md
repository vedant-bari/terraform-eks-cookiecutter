# IRSA Module

## Purpose

Creates IAM Roles for Service Accounts (IRSA).

Supports multiple Kubernetes service accounts.

## Typical Use Cases

- AWS Load Balancer Controller
- External DNS
- External Secrets Operator
- EBS CSI Driver
- EFS CSI Driver
- Karpenter

## Dependencies

Requires:

- EKS Cluster
- OIDC Provider
- IAM Policies

## Outputs

- role_arns
- role_names