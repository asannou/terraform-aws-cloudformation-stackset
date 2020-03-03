provider "aws" {
  alias = "administration"
}

locals {
  execution_role_name = var.administration_role.execution_role_name
}

module "execution_role" {
  source                  = "github.com/asannou/terraform-aws-cloudformation-stackset//execution-role"
  administration_role_arn = var.administration_role.arn
  execution_role_name     = local.execution_role_name
  policy_arns = [
    "arn:aws:iam::aws:policy/AmazonGuardDutyFullAccess",
  ]
}

resource "aws_cloudformation_stack_set" "guardduty" {
  name = "enable-aws-guardduty"
  parameters = {
    MasterId = var.master_id
  }
  template_url            = "https://s3.amazonaws.com/cloudformation-stackset-sample-templates-us-east-1/EnableAWSGuardDuty.yml"
  administration_role_arn = var.administration_role.arn
  execution_role_name     = local.execution_role_name
  depends_on              = [module.execution_role]
  provider                = aws.administration
}

module "instances" {
  source         = "github.com/asannou/terraform-aws-cloudformation-stackset//instances"
  stack_set_name = aws_cloudformation_stack_set.guardduty.name
  module_depends_on = [
    var.administration_role,
    module.execution_role
  ]
  providers = {
    aws.administration = aws.administration
    aws                = aws
  }
}

