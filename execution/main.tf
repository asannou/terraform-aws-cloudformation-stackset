provider "aws" {
  alias = "administration"
}

variable "role_name" {
  type    = string
  default = "AWSCloudFormationStackSetExecutionRole"
}

variable "administration_role_name" {
  type    = string
  default = "AWSCloudFormationStackSetAdministrationRole"
}

data "aws_caller_identity" "administration" {
  provider = aws.administration
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
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.administration.account_id}:role/${var.administration_role_name}"]
    }
  }
}

resource "aws_iam_role_policy_attachment" "cloudformation" {
  role       = aws_iam_role.role.name
  policy_arn = "arn:aws:iam::aws:policy/AWSCloudFormationFullAccess"
}

resource "aws_iam_role_policy_attachment" "s3" {
  role       = aws_iam_role.role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

resource "aws_iam_role_policy_attachment" "sns" {
  role       = aws_iam_role.role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSNSFullAccess"
}

output "role_name" {
  value = aws_iam_role.role.name
}

