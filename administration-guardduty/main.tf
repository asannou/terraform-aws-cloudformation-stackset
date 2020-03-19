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

resource "aws_cloudformation_stack" "guardduty_to_slack" {
  name = "guardduty-to-slack"
  parameters = {
    IncomingWebHookURL = var.incoming_web_hook_url
    SlackChannel       = var.slack_channel
    MinSeverityLevel   = var.min_severity_level
  }
  template_body = file("${path.module}/gd2slack.template.yml")
  capabilities  = ["CAPABILITY_IAM"]
}

resource "aws_lambda_function" "custom_resource" {
  filename         = data.archive_file.lambda.output_path
  function_name    = "guardduty-cloudformation-custom-resource"
  role             = aws_iam_role.lambda.arn
  handler          = "index.handler"
  runtime          = "nodejs12.x"
  timeout          = "60"
  source_code_hash = data.archive_file.lambda.output_base64sha256
}

data "archive_file" "lambda" {
  type        = "zip"
  source_dir  = "${path.module}/custom-resource"
  output_path = "${path.module}/custom-resource.zip"
}

resource "aws_iam_role" "lambda" {
  name               = "LambdaRoleGuardDutyCloudformationCustomResource"
  path               = "/"
  assume_role_policy = data.aws_iam_policy_document.lambda_role.json
}

data "aws_iam_policy_document" "lambda_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy_attachment" "lambda" {
  role       = aws_iam_role.lambda.name
  policy_arn = aws_iam_policy.lambda.arn
}

resource "aws_iam_policy" "lambda" {
  name   = "GuardDutyMemberAccess"
  path   = "/"
  policy = data.aws_iam_policy_document.lambda.json
}

data "aws_iam_policy_document" "lambda" {
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

resource "aws_lambda_permission" "permission" {
  count         = length(var.regions)
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.custom_resource.function_name
  principal     = "sns.amazonaws.com"
  source_arn    = "arn:aws:sns:${var.regions[count.index]}:${data.aws_caller_identity.identity.account_id}:CloudformationCustomResource"
}

resource "aws_cloudwatch_log_group" "lambda_log" {
  name              = "/aws/lambda/${aws_lambda_function.custom_resource.function_name}"
  retention_in_days = 14
}

resource "aws_iam_role_policy_attachment" "lambda_log" {
  role       = aws_iam_role.lambda.name
  policy_arn = aws_iam_policy.lambda_log.arn
}

resource "aws_iam_policy" "lambda_log" {
  name   = "GuardDutyCloudformationCustomResourceLogging"
  path   = "/"
  policy = data.aws_iam_policy_document.lambda_log.json
}

data "aws_iam_policy_document" "lambda_log" {
  statement {
    effect = "Allow"
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = ["arn:aws:logs:*:*:*"]
  }
}

module "master_execution_role" {
  source                  = "github.com/asannou/terraform-aws-cloudformation-stackset//execution-role"
  administration_role_arn = module.administration_role.arn
  execution_role_name     = var.master_execution_role_name
  policy_arns             = [aws_iam_policy.role.arn]
}

resource "aws_iam_policy" "role" {
  name   = "${var.master_execution_role_name}Policy"
  policy = data.aws_iam_policy_document.role.json
}

data "aws_iam_policy_document" "role" {
  statement {
    effect    = "Allow"
    actions   = ["sns:*"]
    resources = ["*"]
  }
}

resource "aws_cloudformation_stack_set" "master" {
  name = "guardduty-master"
  parameters = {
    CloudformationCustomResourceLambdaFunctionArn = aws_lambda_function.custom_resource.arn
    OrganizationId                                = data.aws_organizations_organization.organization.id
  }
  template_body           = file("${path.module}/master.yml")
  administration_role_arn = module.administration_role.arn
  execution_role_name     = var.master_execution_role_name
  depends_on = [
    module.master_execution_role,
    aws_lambda_permission.permission
  ]
}

module "instances" {
  source         = "github.com/asannou/terraform-aws-cloudformation-stackset//instances"
  stack_set_name = aws_cloudformation_stack_set.master.name
  module_depends_on = [
    module.administration_role,
    module.master_execution_role
  ]
  providers = {
    aws.administration = aws
    aws                = aws
  }
}

