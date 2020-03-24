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

module "administration" {
  source         = "github.com/asannou/terraform-aws-cloudformation-stackset//guardduty-administration"
  ipset          = file("ipset.txt")
  threatintelset = file("threatintelset.txt")
  providers = {
    aws = aws.administration
  }
}

module "guardduty-1" {
  source         = "github.com/asannou/terraform-aws-cloudformation-stackset//guardduty"
  administration = module.administration
  providers = {
    aws.administration = aws.administration
    aws                = aws.account-1
  }
}

module "guardduty-2" {
  source         = "github.com/asannou/terraform-aws-cloudformation-stackset//guardduty"
  administration = module.administration
  providers = {
    aws.administration = aws.administration
    aws                = aws.account-2
  }
}

