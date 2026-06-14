data "aws_iam_policy_document" "assume_role" {
  for_each = var.roles

  statement {
    effect = "Allow"

    principals {
      type = "Federated"

      identifiers = [
        var.oidc_provider_arn
      ]
    }

    actions = [
      "sts:AssumeRoleWithWebIdentity"
    ]

    condition {
      test     = "StringEquals"

      variable = "${replace(var.oidc_provider_url, "https://", "")}:sub"

      values = [
        "system:serviceaccount:${each.value.namespace}:${each.value.service_account}"
      ]
    }
  }
}

resource "aws_iam_role" "this" {
  for_each = var.roles

  name               = each.value.role_name
  assume_role_policy = data.aws_iam_policy_document.assume_role[each.key].json

  tags = merge(
    var.tags,
    {
      Name = each.value.role_name
    }
  )
}

resource "aws_iam_role_policy_attachment" "this" {
  for_each = {
    for pair in flatten([
      for role_key, role in var.roles : [
        for policy_arn in role.policy_arns : {
          role_key   = role_key
          policy_arn = policy_arn
        }
      ]
    ]) :
    "${pair.role_key}-${replace(pair.policy_arn, ":", "_")}" => pair
  }

  role       = aws_iam_role.this[each.value.role_key].name
  policy_arn = each.value.policy_arn
}