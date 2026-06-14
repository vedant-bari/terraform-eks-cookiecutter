variable "environment" {
  type = string
}

variable "bucket_name" {
  type = string
}

variable "kms_alias" {
  type = string
}

variable "kms_deletion_window" {
  type    = number
  default = 30
}

variable "enable_key_rotation" {
  type    = bool
  default = true
}

variable "enable_versioning" {
  type    = bool
  default = true
}

variable "create_lock_table" {
  type    = bool
  default = false
}

variable "lock_table_name" {
  type    = string
  default = null
}

variable "tags" {
  type    = map(string)
  default = {}
}