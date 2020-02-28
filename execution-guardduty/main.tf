provider "aws" {
  alias = "administration"
}

variable "role_name" {
  type    = string
  default = "AWSCloudFormationStackSetExecutionGuardDutyRole"
}

variable "administration_role_name" {
  type    = string
  default = "AWSCloudFormationStackSetAdministrationGuardDutyRole"
}

module "execution" {
  source                   = "github.com/asannou/terraform-aws-cloudformation-stackset-role//execution"
  role_name                = var.role_name
  administration_role_name = var.administration_role_name
  providers = {
    aws                = aws
    aws.administration = aws.administration
  }
}

resource "aws_iam_role_policy_attachment" "guardduty" {
  role       = module.execution.role_name
  policy_arn = "arn:aws:iam::aws:policy/AmazonGuardDutyFullAccess"
}

output "role_name" {
  value = module.execution.role_name
}

