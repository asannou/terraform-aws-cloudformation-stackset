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
  bucket = aws_s3_bucket.bucket.id
  policy = data.aws_iam_policy_document.policy.json
}

data "aws_iam_policy_document" "policy" {
  statement {
    effect = "Allow"
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.bucket.arn}/*"]
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

