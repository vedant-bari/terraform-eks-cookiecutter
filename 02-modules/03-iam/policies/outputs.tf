output "policy_arns" {
  description = "ARNs of created policies"

  value = {
    for k, v in aws_iam_policy.this :
    k => v.arn
  }
}

output "policy_names" {
  value = {
    for k, v in aws_iam_policy.this :
    k => v.name
  }
}