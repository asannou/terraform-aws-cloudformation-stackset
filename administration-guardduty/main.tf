module "administration_role" {
  source                   = "github.com/asannou/terraform-aws-cloudformation-stackset//administration-role"
  administration_role_name = var.administration_role_name
  execution_role_name      = var.execution_role_name
}

