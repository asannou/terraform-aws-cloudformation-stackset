locals {
  required_policy_arns = [
    "arn:aws:iam::aws:policy/AWSCloudFormationFullAccess",
    "arn:aws:iam::aws:policy/AmazonS3FullAccess",
    "arn:aws:iam::aws:policy/AmazonSNSFullAccess",
  ]
  policy_arns = concat(
    local.required_policy_arns,
    var.policy_arns
  )
}

resource "aws_iam_role" "role" {
  name               = var.execution_role_name
  assume_role_policy = data.aws_iam_policy_document.role.json
}

data "aws_iam_policy_document" "role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "AWS"
      identifiers = [var.administration_role_arn]
    }
  }
}

resource "aws_iam_role_policy_attachment" "attachments" {
  count      = length(local.policy_arns)
  role       = aws_iam_role.role.name
  policy_arn = local.policy_arns[count.index]
}

