provider "aws" {
  alias = "administration"
}

data "aws_caller_identity" "identity" {}

data "aws_caller_identity" "administration" {
  provider = aws.administration
}

locals {
  execution_role_name = var.administration.role.execution_role_name
  service_role_arn    = "arn:aws:iam::${data.aws_caller_identity.identity.account_id}:role/aws-service-role/guardduty.amazonaws.com/AWSServiceRoleForAmazonGuardDuty"
}

module "execution_role" {
  source                  = "github.com/asannou/terraform-aws-cloudformation-stackset//execution-role"
  administration_role_arn = var.administration.role.arn
  execution_role_name     = local.execution_role_name
  policy_arns             = [aws_iam_policy.policy.arn]
}

resource "aws_iam_policy" "policy" {
  name   = "${local.execution_role_name}Policy"
  policy = data.aws_iam_policy_document.policy.json
}

data "aws_iam_policy_document" "policy" {
  statement {
    effect    = "Allow"
    actions   = ["guardduty:*"]
    resources = ["*"]
  }
  statement {
    effect    = "Allow"
    actions   = ["iam:CreateServiceLinkedRole"]
    resources = [local.service_role_arn]
    condition {
      test     = "StringLike"
      variable = "iam:AWSServiceName"
      values   = ["guardduty.amazonaws.com"]
    }
  }
  statement {
    effect = "Allow"
    actions = [
      "iam:PutRolePolicy",
      "iam:DeleteRolePolicy",
    ]
    resources = [local.service_role_arn]
  }
}

resource "aws_cloudformation_stack_set" "guardduty" {
  name = "guardduty-member"
  parameters = {
    MasterId                   = data.aws_caller_identity.administration.account_id
    Email                      = var.email
    FindingPublishingFrequency = var.finding_publishing_frequency
  }
  template_body           = file("${path.module}/member.yml")
  administration_role_arn = var.administration.role.arn
  execution_role_name     = local.execution_role_name
  depends_on              = [module.execution_role]
  provider                = aws.administration
}

module "instances" {
  source         = "github.com/asannou/terraform-aws-cloudformation-stackset//instances"
  stack_set_name = aws_cloudformation_stack_set.guardduty.name
  module_depends_on = [
    var.administration,
    module.execution_role,
    aws_cloudformation_stack_set.guardduty
  ]
  providers = {
    aws.administration = aws.administration
    aws                = aws
  }
}

