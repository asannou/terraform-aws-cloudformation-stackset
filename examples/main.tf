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

data "aws_caller_identity" "administration" {
  provider = aws.administration
}

locals {
  administrator_account_id = data.aws_caller_identity.administration.account_id
}

module "administration" {
  source = "github.com/asannou/terraform-aws-cloudformation-stackset-role//administration"
  providers = {
    aws = aws.administration
  }
}

module "execution-1" {
  source                   = "github.com/asannou/terraform-aws-cloudformation-stackset-role//execution"
  administrator_account_id = local.administrator_account_id
  providers = {
    aws = aws.execution-1
  }
}

module "execution-2" {
  source                   = "github.com/asannou/terraform-aws-cloudformation-stackset-role//execution"
  administrator_account_id = local.administrator_account_id
  providers = {
    aws = aws.execution-2
  }
}

