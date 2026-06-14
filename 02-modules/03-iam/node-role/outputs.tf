output "node_role_arn" {
  description = "ARN of the EKS node role"

  value = aws_iam_role.eks_node_role.arn
}

output "node_role_name" {
  description = "Name of the EKS node role"

  value = aws_iam_role.eks_node_role.name
}

output "instance_profile_arn" {
  description = "ARN of the instance profile"

  value = aws_iam_instance_profile.eks_node_profile.arn
}

output "instance_profile_name" {
  description = "Name of the instance profile"

  value = aws_iam_instance_profile.eks_node_profile.name
}