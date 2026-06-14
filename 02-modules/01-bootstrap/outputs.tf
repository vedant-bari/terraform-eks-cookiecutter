output "bucket_name" {
  value = aws_s3_bucket.terraform_state.bucket
}

output "bucket_arn" {
  value = aws_s3_bucket.terraform_state.arn
}

output "kms_key_arn" {
  value = aws_kms_key.terraform.arn
}

output "kms_key_id" {
  value = aws_kms_key.terraform.key_id
}

output "kms_alias" {
  value = aws_kms_alias.terraform.name
}

output "lock_table_name" {
  value = try(
    aws_dynamodb_table.terraform_lock[0].name,
    null
  )
}