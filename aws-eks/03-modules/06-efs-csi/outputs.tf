output "file_system_id" {
  description = "ID of the EFS file system used by the EFS CSI StorageClass."
  value       = local.file_system_id
}

output "storage_class_name" {
  description = "Kubernetes StorageClass that dynamically provisions EFS access points."
  value       = kubernetes_storage_class_v1.efs.metadata[0].name
}

output "efs_csi_role_arn" {
  description = "IAM role assumed by the EFS CSI controller service account."
  value       = aws_iam_role.efs_csi.arn
}
