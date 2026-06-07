variable "aws_region" {
  description = "AWS Region"
  type        = string
  default     = "ap-south-1"
}

variable "project_name" {
  description = "Project Name"
  type        = string
}

variable "environment" {
  description = "Environment Name"
  type        = string
  default     = "shared"
}

variable "backend_bucket_name" {
  description = "Terraform State Bucket Name"
  type        = string
}

variable "lock_table_name" {
  description = "Terraform Lock Table Name"
  type        = string
  default     = "terraform-locks"
}