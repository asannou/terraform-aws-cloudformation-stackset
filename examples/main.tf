variable "region" {
  type = string
}

provider "aws" {
  region = var.region
  alias  = "administration"
}

provider "aws" {
  region  = var.region
  profile = "execution-1"
  alias   = "execution-1"
}

provider "aws" {
  region  = var.region
  profile = "execution-2"
  alias   = "execution-2"
}

locals {
  administration_role_name = "AWSCloudFormationStackSetAdministrationGuardDutyRole"
  execution_role_name      = "AWSCloudFormationStackSetExecutionGuardDutyRole"
}

module "administration" {
  source              = "github.com/asannou/terraform-aws-cloudformation-stackset-role//administration"
  role_name           = local.administration_role_name
  execution_role_name = local.execution_role_name
  providers = {
    aws = aws.administration
  }
}

module "execution-1" {
  source                   = "github.com/asannou/terraform-aws-cloudformation-stackset-role//execution-guardduty"
  role_name                = local.execution_role_name
  administration_role_name = local.administration_role_name
  providers = {
    aws                = aws.execution-1
    aws.administration = aws.administration
  }
}

module "execution-2" {
  source                   = "github.com/asannou/terraform-aws-cloudformation-stackset-role//execution-guardduty"
  role_name                = local.execution_role_name
  administration_role_name = local.administration_role_name
  providers = {
    aws                = aws.execution-2
    aws.administration = aws.administration
  }
}

