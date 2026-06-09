output "backend_bucket_name" {

  description = "Terraform State Bucket"

  value = aws_s3_bucket.terraform_state.bucket
}


output "dynamodb_lock_table" {

  description = "Terraform Lock Table"

  value = aws_dynamodb_table.terraform_lock.name
}

output "kms_key_arn" {

  description = "Terraform State KMS Key"

  value = aws_kms_key.terraform_state.arn
}

output "kms_alias" {

  description = "Terraform State KMS Alias"

  value = aws_kms_alias.terraform_state.name
}
