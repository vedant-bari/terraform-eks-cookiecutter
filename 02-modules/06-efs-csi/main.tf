data "aws_eks_cluster" "this" {
  name = var.cluster_name
}

data "aws_eks_cluster_auth" "this" {
  name = var.cluster_name
}

data "aws_efs_file_system" "existing" {
  count = var.create_efs ? 0 : 1

  file_system_id = var.existing_efs_file_system_id
}

locals {
  file_system_id = var.create_efs ? aws_efs_file_system.this[0].id : data.aws_efs_file_system.existing[0].id
}

data "aws_iam_policy_document" "efs_csi_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(var.cluster_oidc_issuer_url, "https://", "")}:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(var.cluster_oidc_issuer_url, "https://", "")}:sub"
      values   = ["system:serviceaccount:kube-system:efs-csi-controller-sa"]
    }
  }
}

resource "aws_iam_role" "efs_csi" {
  name               = "${var.cluster_name}-efs-csi-driver"
  assume_role_policy = data.aws_iam_policy_document.efs_csi_assume_role.json
  tags               = var.tags
}

resource "aws_iam_role_policy_attachment" "efs_csi" {
  role       = aws_iam_role.efs_csi.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEFSCSIDriverPolicy"
}

resource "aws_efs_file_system" "this" {
  count = var.create_efs ? 1 : 0

  creation_token   = "${var.cluster_name}-efs"
  encrypted        = true
  performance_mode = "generalPurpose"
  throughput_mode  = "bursting"

  lifecycle_policy {
    transition_to_ia = var.transition_to_ia
  }

  tags = merge(var.tags, {
    Name = "${var.cluster_name}-efs"
  })
}

resource "aws_security_group" "efs" {
  count = var.create_efs ? 1 : 0

  name        = "${var.cluster_name}-efs-sg"
  description = "Allow NFS traffic from EKS worker nodes to EFS"
  vpc_id      = var.vpc_id

  ingress {
    description     = "NFS from EKS worker nodes"
    from_port       = 2049
    to_port         = 2049
    protocol        = "tcp"
    security_groups = [var.node_security_group_id]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.cluster_name}-efs-sg"
  })
}

resource "aws_efs_mount_target" "this" {
  for_each = var.create_efs ? toset(var.private_subnet_ids) : toset([])

  file_system_id  = local.file_system_id
  subnet_id       = each.value
  security_groups = [aws_security_group.efs[0].id]
}

resource "aws_eks_addon" "efs_csi" {
  cluster_name                = var.cluster_name
  addon_name                  = "aws-efs-csi-driver"
  addon_version               = var.addon_version
  service_account_role_arn    = aws_iam_role.efs_csi.arn
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  depends_on = [aws_iam_role_policy_attachment.efs_csi]
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.this.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.this.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.this.token
}

resource "kubernetes_storage_class_v1" "efs" {
  metadata {
    name = var.storage_class_name
  }

  storage_provisioner = "efs.csi.aws.com"
  reclaim_policy      = var.reclaim_policy
  volume_binding_mode = "Immediate"
  parameters = {
    provisioningMode = "efs-ap"
    fileSystemId     = local.file_system_id
    directoryPerms   = "700"
    basePath         = var.access_point_base_path
  }

  depends_on = [aws_eks_addon.efs_csi, aws_efs_mount_target.this]
}
