variable "stack_name" {
  type    = string
  default = "cloudformation-stackset-administration-role"
}

resource "aws_cloudformation_stack" "role" {
  name         = var.stack_name
  template_url = "https://s3.amazonaws.com/cloudformation-stackset-sample-templates-us-east-1/AWSCloudFormationStackSetAdministrationRole.yml"
  capabilities = ["CAPABILITY_NAMED_IAM"]
}

