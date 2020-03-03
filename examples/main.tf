variable "region" {
  type = string
}

provider "aws" {
  region  = var.region
  profile = "account-0"
  alias   = "administration"
}

provider "aws" {
  region  = var.region
  profile = "account-1"
  alias   = "account-1"
}

provider "aws" {
  region  = var.region
  profile = "account-2"
  alias   = "account-2"
}

module "administration_role" {
  source                   = "github.com/asannou/terraform-aws-cloudformation-stackset//administration-role"
  administration_role_name = "AWSCloudFormationStackSetAdministrationGuardDutyRole"
  execution_role_name      = "AWSCloudFormationStackSetExecutionGuardDutyRole"
  providers = {
    aws = aws.administration
  }
}

module "guardduty-1" {
  source              = "github.com/asannou/terraform-aws-cloudformation-stackset//guardduty"
  administration_role = module.administration_role
  providers = {
    aws.administration = aws.administration
    aws                = aws.account-1
  }
}

module "guardduty-2" {
  source              = "github.com/asannou/terraform-aws-cloudformation-stackset//guardduty"
  administration_role = module.administration_role
  providers = {
    aws.administration = aws.administration
    aws                = aws.account-2
  }
}

