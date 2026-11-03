output "bastion_instance_id" {
  description = "ID of the bastion EC2 instance"
  value       = try(aws_instance.bastion[0].id, null)
}

output "bastion_public_ip" {
  description = "Public IPv4 address of the bastion EC2 instance"
  value       = try(aws_instance.bastion[0].public_ip, null)
}

output "bastion_private_ip" {
  description = "Private IPv4 address of the bastion EC2 instance"
  value       = try(aws_instance.bastion[0].private_ip, null)
}

output "bastion_security_group_id" {
  description = "ID of the bastion security group"
  value       = try(aws_security_group.bastion_sg[0].id, null)
}

output "bastion_iam_role_arn" {
  description = "ARN of the IAM role attached to the bastion"
  value       = var.create_bastion ? (var.existing_role_arn != "" ? var.existing_role_arn : aws_iam_role.bastion[0].arn) : null
}
