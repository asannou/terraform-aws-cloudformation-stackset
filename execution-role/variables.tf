variable "administration_role_arn" {
  type = string
}

variable "execution_role_name" {
  type    = string
  default = "AWSCloudFormationStackSetExecutionRole"
}

variable "policy_arns" {
  type    = list
  default = []
}

