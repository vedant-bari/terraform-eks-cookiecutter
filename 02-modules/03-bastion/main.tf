resource "aws_security_group" "bastion_sg" {
  count       = var.create_bastion ? 1 : 0
  name        = "${var.project_name}-${var.environment}-bastion-sg"
  description = "Allow SSH inbound traffic for Bastion Host"
  vpc_id      = var.vpc_id

  dynamic "ingress" {
    for_each = var.ingress_rules
    content {
      description = lookup(ingress.value, "description", "SSH Inbound")
      from_port   = ingress.value.from_port
      to_port     = ingress.value.to_port
      protocol    = ingress.value.protocol
      cidr_blocks = ingress.value.cidr_blocks
    }
  }

  dynamic "egress" {
    for_each = var.egress_rules
    content {
      description = lookup(egress.value, "description", "Outbound Traffic")
      from_port   = egress.value.from_port
      to_port     = egress.value.to_port
      protocol    = egress.value.protocol
      cidr_blocks = egress.value.cidr_blocks
    }
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-bastion-sg"
  })
}

data "aws_ami" "amazon_linux" {
  count       = var.create_bastion && var.ami_id == null ? 1 : 0
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-kernel-6.1-x86_64"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

data "aws_iam_role" "existing" {
  count = var.create_bastion && var.existing_role_arn != "" ? 1 : 0
  name  = element(reverse(split("/", var.existing_role_arn)), 0)
}

data "aws_iam_policy_document" "bastion_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "bastion" {
  count              = var.create_bastion && var.existing_role_arn == "" ? 1 : 0
  name               = "${var.project_name}-${var.environment}-bastion-role"
  assume_role_policy = data.aws_iam_policy_document.bastion_assume_role.json

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-bastion-role"
  })
}

resource "aws_iam_role_policy_attachment" "ssm" {
  count      = var.create_bastion && var.existing_role_arn == "" ? 1 : 0
  role       = aws_iam_role.bastion[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "bastion" {
  count = var.create_bastion ? 1 : 0
  name  = "${var.project_name}-${var.environment}-bastion-profile"
  role  = var.existing_role_arn != "" ? data.aws_iam_role.existing[0].name : aws_iam_role.bastion[0].name

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-bastion-profile"
  })
}

resource "aws_instance" "bastion" {
  count = var.create_bastion ? 1 : 0

  ami                         = var.ami_id != null ? var.ami_id : data.aws_ami.amazon_linux[0].id
  instance_type               = var.instance_type
  subnet_id                   = var.public_subnet_id
  vpc_security_group_ids      = [aws_security_group.bastion_sg[0].id]
  iam_instance_profile        = aws_iam_instance_profile.bastion[0].name
  associate_public_ip_address = true
  monitoring                  = var.detailed_monitoring
  user_data = var.bastion_password == null ? null : templatefile("${path.module}/user_data.sh.tftpl", {
    username     = var.bastion_username
    password_b64 = base64encode(var.bastion_password)
  })

  root_block_device {
    encrypted   = true
    volume_type = "gp3"
    volume_size = var.root_volume_size
  }

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  lifecycle {
    precondition {
      condition     = trimspace(var.public_subnet_id) != ""
      error_message = "public_subnet_id must be provided when create_bastion is true."
    }
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-bastion"
  })
}
