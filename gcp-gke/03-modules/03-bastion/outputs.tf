output "bastion_name" {
  value       = module.bastion.hostname
  description = "The hostname of the bastion instance."
}

output "bastion_ip" {
  value       = module.bastion.ip_address
  description = "The internal IP address of the bastion host."
}