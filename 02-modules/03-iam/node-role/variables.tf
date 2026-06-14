variable "role_name" {
  description = "Name of the EKS node IAM role"
  type        = string
}

variable "tags" {
  description = "Tags applied to IAM resources"
  type        = map(string)

  default = {}
}