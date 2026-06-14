output "role_arns" {
  value = {
    for k, v in aws_iam_role.this :
    k => v.arn
  }
}

output "role_names" {
  value = {
    for k, v in aws_iam_role.this :
    k => v.name
  }
}