variable "policies" {
  description = "Map of IAM policies"

  type = map(object({
    name        = string
    description = string
    policy      = any
  }))
}

variable "tags" {
  type    = map(string)
  default = {}
}