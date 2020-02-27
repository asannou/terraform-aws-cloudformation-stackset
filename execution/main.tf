variable "stack_name" {
  type    = string
  default = "cloudformation-stackset-execution-role"
}

variable "administrator_account_id" {
  type = string
}

resource "aws_cloudformation_stack" "role" {
  name         = var.stack_name
  template_url = "https://s3.amazonaws.com/cloudformation-stackset-sample-templates-us-east-1/AWSCloudFormationStackSetExecutionRole.yml"
  parameters = {
    AdministratorAccountId = var.administrator_account_id
  }
  capabilities = ["CAPABILITY_NAMED_IAM"]
}

