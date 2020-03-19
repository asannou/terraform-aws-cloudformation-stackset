variable "administration_role_name" {
  type    = string
  default = "AWSCloudFormationStackSetGuardDutyAdministrationRole"
}

variable "execution_role_name" {
  type    = string
  default = "AWSCloudFormationStackSetGuardDutyExecutionRole"
}

variable "master_execution_role_name" {
  type    = string
  default = "AWSCloudFormationStackSetGuardDutyMasterExecutionRole"
}

variable "incoming_web_hook_url" {
  type    = string
  default = null
}

variable "slack_channel" {
  type    = string
  default = null
}

variable "min_severity_level" {
  type    = string
  default = null
}

