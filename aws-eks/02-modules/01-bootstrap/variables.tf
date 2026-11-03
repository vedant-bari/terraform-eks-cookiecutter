variable "bucket_name" {
  type        = string
  description = "The globally unique name of the S3 state storage bucket."
}

variable "force_destroy" {
  type        = bool
  default     = false
  description = "A boolean that all objects should be deleted from the bucket so that the bucket can be destroyed without error."
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Resource tags derived from platform configuration."
}