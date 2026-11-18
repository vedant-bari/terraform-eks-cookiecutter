output "block_storage_class_name" {
  description = "Default EBS gp3 StorageClass (GCP: standard-rwo)."
  value       = kubernetes_storage_class_v1.gp3.metadata[0].name
}

output "rwx_storage_class_name" {
  description = "EFS ReadWriteMany StorageClass (GCP: Filestore class)."
  value       = kubernetes_storage_class_v1.rwx.metadata[0].name
}

output "efs_file_system_id" {
  description = "ID of the shared EFS file system."
  value       = aws_efs_file_system.shared.id
}

output "efs_security_group_id" {
  description = "Security group on the EFS mount targets."
  value       = aws_security_group.efs.id
}
