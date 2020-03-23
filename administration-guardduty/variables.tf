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

variable "create_detector" {
  type    = string
  default = "true"
}

variable "finding_publishing_frequency" {
  type    = string
  default = "FIFTEEN_MINUTES"
}

variable "incoming_web_hook_url" {
  type        = string
  description = "Your unique Incoming Web Hook URL from slack service"
  default     = "https://hooks.slack.com/services/XXXXXX/YYYYY/REPLACE_WITH_YOURS"
}

variable "slack_channel" {
  type        = string
  description = "The slack channel to send findings to"
  default     = "#general"
}

variable "min_severity_level" {
  type        = string
  description = "The minimum findings severity to send to your slack channel (LOW, MEDIUM or HIGH)"
  default     = "LOW"
}

