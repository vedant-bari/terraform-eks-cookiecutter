variable "yaml_path" {
  type = string
}

variable "cluster_endpoint" {
  type = string
}

variable "cluster_ca_certificate" {
  type = string
}

variable "dockerhub_username" {
  type    = string
  default = "testuser40"
}

variable "dockerhub_token" {
  type      = string
  sensitive = true
}

variable "project_id" { 
  type = string 
}

