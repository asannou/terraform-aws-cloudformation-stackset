variable "role_name" {
  type    = string
  default = "AWSCloudFormationStackSetAdministrationRole"
}

variable "execution_role_name" {
  type    = string
  default = "AWSCloudFormationStackSetExecutionRole"
}

resource "aws_iam_role" "role" {
  name               = var.role_name
  assume_role_policy = data.aws_iam_policy_document.role.json
}

data "aws_iam_policy_document" "role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["cloudformation.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy" "policy" {
  name   = "AssumeRole-${var.execution_role_name}"
  role   = aws_iam_role.role.name
  policy = data.aws_iam_policy_document.policy.json
}

data "aws_iam_policy_document" "policy" {
  statement {
    effect    = "Allow"
    actions   = ["sts:AssumeRole"]
    resources = ["arn:aws:iam::*:role/${var.execution_role_name}"]
  }
}

output "role_name" {
  value = aws_iam_role.role.name
}

