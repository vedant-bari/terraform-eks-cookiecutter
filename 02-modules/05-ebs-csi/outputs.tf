output "storage_class_name" {
  description = "Kubernetes StorageClass that dynamically provisions gp3 EBS volumes."
  value       = kubernetes_storage_class_v1.ebs_gp3.metadata[0].name
}

output "ebs_csi_role_arn" {
  description = "IAM role assumed by the EBS CSI controller service account."
  value       = aws_iam_role.ebs_csi.arn
}

output "existing_ebs_pvc_name" {
  description = "Name of the claim bound to an existing EBS volume, or null when dynamic provisioning is enabled."
  value       = try(kubernetes_persistent_volume_claim_v1.existing[0].metadata[0].name, null)
}
