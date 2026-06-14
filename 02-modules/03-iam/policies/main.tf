resource "aws_iam_policy" "this" {
  for_each = var.policies

  name        = each.value.name
  description = each.value.description

  policy = jsonencode(each.value.policy)

  tags = merge(
    var.tags,
    {
      Name = each.value.name
    }
  )
}