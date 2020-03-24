data "aws_region" "region" {}

data "aws_caller_identity" "identity" {}

data "aws_organizations_organization" "organization" {}

module "administration_role" {
  source                   = "github.com/asannou/terraform-aws-cloudformation-stackset//administration-role"
  administration_role_name = var.administration_role_name
  execution_role_name      = var.execution_role_name
}

resource "aws_s3_bucket" "bucket" {
  bucket_prefix = "aws-guardduty-"
  acl           = "private"
}

resource "aws_s3_bucket_public_access_block" "block" {
  bucket                  = aws_s3_bucket.bucket.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_policy" "policy" {
  bucket     = aws_s3_bucket.bucket.id
  policy     = data.aws_iam_policy_document.bucket_policy.json
  depends_on = [aws_s3_bucket_public_access_block.block]
}

data "aws_iam_policy_document" "bucket_policy" {
  statement {
    effect = "Allow"
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.bucket.arn}/*"]
    condition {
      test     = "ArnLike"
      variable = "aws:PrincipalArn"
      values   = ["arn:aws:iam::*:role/aws-service-role/guardduty.amazonaws.com/AWSServiceRoleForAmazonGuardDuty"]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:PrincipalOrgID"
      values   = [data.aws_organizations_organization.organization.id]
    }
  }
}

resource "aws_s3_bucket_object" "ipset" {
  bucket  = aws_s3_bucket.bucket.id
  acl     = "private"
  content = file("ipset.txt")
  key     = "ipset.txt"
}

resource "aws_s3_bucket_object" "threatintelset" {
  bucket  = aws_s3_bucket.bucket.id
  acl     = "private"
  content = file("threatintelset.txt")
  key     = "threatintelset.txt"
}

resource "aws_lambda_function" "guardduty_to_slack" {
  filename         = data.archive_file.guardduty_to_slack.output_path
  function_name    = "guardduty-to-slack"
  description      = "Lambda to push GuardDuty findings to slack"
  role             = aws_iam_role.guardduty_to_slack.arn
  handler          = "index.handler"
  runtime          = "nodejs12.x"
  timeout          = "10"
  source_code_hash = data.archive_file.guardduty_to_slack.output_base64sha256
  environment {
    variables = {
      webHookUrl       = var.incoming_web_hook_url
      slackChannel     = var.slack_channel
      minSeverityLevel = var.min_severity_level
    }
  }
}

data "archive_file" "guardduty_to_slack" {
  type        = "zip"
  source_dir  = "${path.module}/gd2slack"
  output_path = "${path.module}/gd2slack.zip"
}

resource "aws_iam_role" "guardduty_to_slack" {
  name               = "LambdaRoleGuardDutyToSlack"
  path               = "/"
  assume_role_policy = data.aws_iam_policy_document.guardduty_to_slack.json
}

data "aws_iam_policy_document" "guardduty_to_slack" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

locals {
  guardduty_to_slack_policy_arns = [
    "arn:aws:iam::aws:policy/AWSXrayWriteOnlyAccess",
    "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole",
    "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole",
  ]
}

resource "aws_iam_role_policy_attachment" "guardduty_to_slack" {
  count      = length(local.guardduty_to_slack_policy_arns)
  role       = aws_iam_role.guardduty_to_slack.name
  policy_arn = local.guardduty_to_slack_policy_arns[count.index]
}

resource "aws_lambda_permission" "guardduty_to_slack" {
  count         = length(var.regions)
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.guardduty_to_slack.function_name
  principal     = "sns.amazonaws.com"
  source_arn    = "arn:aws:sns:${var.regions[count.index]}:${data.aws_caller_identity.identity.account_id}:GuardDuty"
}

resource "aws_cloudwatch_log_group" "guardduty_to_slack" {
  name              = "/aws/lambda/${aws_lambda_function.guardduty_to_slack.function_name}"
  retention_in_days = 14
}

resource "aws_iam_role_policy_attachment" "guardduty_to_slack_log" {
  role       = aws_iam_role.guardduty_to_slack.name
  policy_arn = aws_iam_policy.guardduty_to_slack_log.arn
}

resource "aws_iam_policy" "guardduty_to_slack_log" {
  name   = "GuardDutyToSlackLambdaLogging"
  path   = "/"
  policy = data.aws_iam_policy_document.guardduty_to_slack_log.json
}

data "aws_iam_policy_document" "guardduty_to_slack_log" {
  statement {
    effect = "Allow"
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = ["arn:aws:logs:${data.aws_region.region.name}:${data.aws_caller_identity.identity.account_id}:log-group:${aws_cloudwatch_log_group.guardduty_to_slack.name}:*"]
  }
}

resource "aws_lambda_function" "custom_resource" {
  filename         = data.archive_file.custom_resource.output_path
  function_name    = "guardduty-cloudformation-custom-resource"
  role             = aws_iam_role.custom_resource.arn
  handler          = "index.handler"
  runtime          = "nodejs12.x"
  timeout          = "60"
  source_code_hash = data.archive_file.custom_resource.output_base64sha256
}

data "archive_file" "custom_resource" {
  type        = "zip"
  source_dir  = "${path.module}/custom-resource"
  output_path = "${path.module}/custom-resource.zip"
}

resource "aws_iam_role" "custom_resource" {
  name               = "LambdaRoleGuardDutyCloudformationCustomResource"
  path               = "/"
  assume_role_policy = data.aws_iam_policy_document.custom_resource_role.json
}

data "aws_iam_policy_document" "custom_resource_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy_attachment" "custom_resource" {
  role       = aws_iam_role.custom_resource.name
  policy_arn = aws_iam_policy.custom_resource.arn
}

resource "aws_iam_policy" "custom_resource" {
  name   = "GuardDutyMemberAccess"
  path   = "/"
  policy = data.aws_iam_policy_document.custom_resource.json
}

data "aws_iam_policy_document" "custom_resource" {
  statement {
    effect = "Allow"
    actions = [
      "guardduty:DeleteMembers",
      "guardduty:CreateMembers",
      "guardduty:InviteMembers",
      "guardduty:ListDetectors",
    ]
    resources = ["*"]
  }
}

resource "aws_lambda_permission" "custom_resource" {
  count         = length(var.regions)
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.custom_resource.function_name
  principal     = "sns.amazonaws.com"
  source_arn    = "arn:aws:sns:${var.regions[count.index]}:${data.aws_caller_identity.identity.account_id}:CloudformationCustomResource"
}

resource "aws_cloudwatch_log_group" "custom_resource" {
  name              = "/aws/lambda/${aws_lambda_function.custom_resource.function_name}"
  retention_in_days = 14
}

resource "aws_iam_role_policy_attachment" "custom_resource_log" {
  role       = aws_iam_role.custom_resource.name
  policy_arn = aws_iam_policy.custom_resource_log.arn
}

resource "aws_iam_policy" "custom_resource_log" {
  name   = "GuardDutyCloudformationCustomResourceLogging"
  path   = "/"
  policy = data.aws_iam_policy_document.custom_resource_log.json
}

data "aws_iam_policy_document" "custom_resource_log" {
  statement {
    effect = "Allow"
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = ["arn:aws:logs:${data.aws_region.region.name}:${data.aws_caller_identity.identity.account_id}:log-group:${aws_cloudwatch_log_group.custom_resource.name}:*"]
  }
}

module "master_execution_role" {
  source                  = "github.com/asannou/terraform-aws-cloudformation-stackset//execution-role"
  administration_role_arn = module.administration_role.arn
  execution_role_name     = var.master_execution_role_name
  policy_arns = [
    "arn:aws:iam::aws:policy/CloudWatchEventsFullAccess",
    "arn:aws:iam::aws:policy/AmazonSNSFullAccess",
    "arn:aws:iam::aws:policy/AmazonGuardDutyFullAccess",
    "arn:aws:iam::aws:policy/IAMFullAccess",
  ]
}

resource "aws_cloudformation_stack_set" "master" {
  name = "guardduty-master"
  parameters = {
    FindingPublishingFrequency                    = var.finding_publishing_frequency
    IPSetLocation                                 = "s3://${aws_s3_bucket_object.ipset.bucket}/${aws_s3_bucket_object.ipset.key}"
    ThreatIntelSetLocation                        = "s3://${aws_s3_bucket_object.threatintelset.bucket}/${aws_s3_bucket_object.threatintelset.key}"
    GuardDutyLambdaFunctionArn                    = aws_lambda_function.guardduty_to_slack.arn
    CloudformationCustomResourceLambdaFunctionArn = aws_lambda_function.custom_resource.arn
    ExecutionRoleName                             = var.execution_role_name
    OrganizationId                                = data.aws_organizations_organization.organization.id
  }
  template_body           = file("${path.module}/master.yml")
  administration_role_arn = module.administration_role.arn
  execution_role_name     = var.master_execution_role_name
  depends_on = [
    module.master_execution_role,
    aws_lambda_permission.custom_resource
  ]
}

module "instances" {
  source         = "github.com/asannou/terraform-aws-cloudformation-stackset//instances"
  stack_set_name = aws_cloudformation_stack_set.master.name
  module_depends_on = [
    module.administration_role,
    module.master_execution_role,
    aws_cloudformation_stack_set.master
  ]
  providers = {
    aws.administration = aws
    aws                = aws
  }
}

