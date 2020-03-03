provider "aws" {
  alias = "administration"
}

data "aws_caller_identity" "identity" {}

resource "aws_cloudformation_stack_set_instance" "instances" {
  count          = length(var.regions)
  region         = var.regions[count.index]
  account_id     = data.aws_caller_identity.identity.account_id
  stack_set_name = var.stack_set_name
  depends_on     = [var.module_depends_on]
  provider       = aws.administration
}

