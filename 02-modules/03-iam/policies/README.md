# IAM Policies Module

## Purpose

Creates reusable customer-managed IAM policies.

These policies can later be attached to:

- IRSA Roles
- IAM Users
- IAM Roles
- Future EKS Add-ons

## Example

```hcl
policies = {
  external_dns = {
    name        = "external-dns-policy"
    description = "Permissions for External DNS"

    policy = {
      Version = "2012-10-17"

      Statement = [
        {
          Effect = "Allow"

          Action = [
            "route53:ChangeResourceRecordSets"
          ]

          Resource = ["*"]
        }
      ]
    }
  }
}
```

## Outputs

- policy_arns
- policy_names