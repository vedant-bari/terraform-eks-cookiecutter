output "state_bucket_name" {
  description = "Name of the S3 bucket that holds Terragrunt state."
  value       = aws_s3_bucket.tf_state.id
}

output "state_bucket_arn" {
  description = "ARN of the S3 state bucket."
  value       = aws_s3_bucket.tf_state.arn
}

output "deploy_role_arn" {
  description = "ARN of the IAM role Terragrunt assumes for every later layer."
  value       = aws_iam_role.deploy.arn
}
