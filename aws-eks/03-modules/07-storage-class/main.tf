# ==============================================================================
# 07-storage-class: AWS counterpart of gcp-gke/03-modules/07-storage-class.
#
# GCP: one Filestore-CSI StorageClass (RWX) plus the built-in standard-rwo.
# AWS:
#   - gp3 EBS StorageClass, encrypted, marked default (EKS ships no usable default)
#   - one encrypted EFS file system with a mount target per private subnet and a
#     dynamic-provisioning StorageClass. Each PVC becomes an EFS access point,
#     not a separate 1 TiB Filestore instance.
# ==============================================================================

provider "kubernetes" {
  host                   = var.cluster_endpoint
  cluster_ca_certificate = base64decode(var.cluster_certificate_authority_data)

  # EKS tokens last 15 minutes, so fetch one on demand instead of a static token.
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args = concat(
      ["eks", "get-token", "--cluster-name", var.cluster_name, "--region", var.region, "--output", "json"],
      var.kube_role_arn != "" ? ["--role-arn", var.kube_role_arn] : [],
      var.aws_profile != "" ? ["--profile", var.aws_profile] : [],
    )
  }
}

# ------------------------------------------------------------------------------
# Block storage
# ------------------------------------------------------------------------------

resource "kubernetes_storage_class_v1" "gp3" {
  metadata {
    name = var.block_storage_class_name
    annotations = {
      "storageclass.kubernetes.io/is-default-class" = "true"
    }
  }

  storage_provisioner    = "ebs.csi.aws.com"
  reclaim_policy         = "Delete"
  volume_binding_mode    = "WaitForFirstConsumer" # create the volume in the pod's AZ
  allow_volume_expansion = true

  parameters = merge(
    {
      type      = "gp3"
      encrypted = "true"
    },
    var.block_kms_key_arn != "" ? { kmsKeyId = var.block_kms_key_arn } : {}
  )
}

# ------------------------------------------------------------------------------
# EFS
# ------------------------------------------------------------------------------

resource "aws_security_group" "efs" {
  name        = "${var.name_prefix}-efs"
  description = "NFS from EKS nodes to the shared EFS file system"
  vpc_id      = var.vpc_id

  tags = {
    Name = "${var.name_prefix}-efs"
  }
}

resource "aws_vpc_security_group_ingress_rule" "efs_nfs" {
  for_each = toset(var.nfs_client_security_group_ids)

  security_group_id            = aws_security_group.efs.id
  description                  = "NFS from ${each.value}"
  ip_protocol                  = "tcp"
  from_port                    = 2049
  to_port                      = 2049
  referenced_security_group_id = each.value
}

resource "aws_efs_file_system" "shared" {
  creation_token   = "${var.name_prefix}-shared"
  encrypted        = true
  performance_mode = "generalPurpose"
  throughput_mode  = var.efs_throughput_mode

  dynamic "lifecycle_policy" {
    for_each = var.efs_transition_to_ia != "" ? [var.efs_transition_to_ia] : []
    content {
      transition_to_ia = lifecycle_policy.value
    }
  }

  tags = {
    Name = "${var.name_prefix}-shared"
  }
}

resource "aws_efs_backup_policy" "shared" {
  file_system_id = aws_efs_file_system.shared.id

  backup_policy {
    status = var.efs_backup_enabled ? "ENABLED" : "DISABLED"
  }
}

# One mount target per private subnet, so pods in any AZ can mount it.
resource "aws_efs_mount_target" "shared" {
  for_each = { for i, id in var.private_subnet_ids : tostring(i) => id }

  file_system_id  = aws_efs_file_system.shared.id
  subnet_id       = each.value
  security_groups = [aws_security_group.efs.id]
}

resource "kubernetes_storage_class_v1" "rwx" {
  metadata {
    name = var.rwx_storage_class_name
  }

  storage_provisioner    = "efs.csi.aws.com"
  reclaim_policy         = "Delete"
  volume_binding_mode    = "Immediate" # GCP parity; EFS is reachable from every AZ
  allow_volume_expansion = true        # Accepted for parity; EFS ignores sizes

  parameters = {
    provisioningMode = "efs-ap"
    fileSystemId     = aws_efs_file_system.shared.id
    directoryPerms   = var.efs_directory_perms
    uid              = tostring(var.efs_uid)
    gid              = tostring(var.efs_gid)
    basePath         = "/dynamic"
  }

  # A PVC created before the mount targets are available would fail to mount.
  depends_on = [aws_efs_mount_target.shared]
}
