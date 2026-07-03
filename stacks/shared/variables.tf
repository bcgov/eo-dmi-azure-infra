variable "ministry_code" {
  description = "Short BC Gov ministry code used in resource naming (e.g. \"citz\"). See docs/platform-guide.md \"Naming conventions\"."
  type        = string
}

variable "program_code" {
  description = "Short program code used in resource naming (e.g. \"pmt\")."
  type        = string
}

variable "environment" {
  description = "Environment short name this stack instance is deployed into."
  type        = string

  validation {
    condition     = contains(["tools", "dev", "test", "prod"], var.environment)
    error_message = "environment must be one of: tools, dev, test, prod."
  }
}

variable "subscription_id" {
  description = "Subscription ID for b9cee3-<environment>."
  type        = string
}

variable "location" {
  description = "Azure region for shared resources."
  type        = string
  default     = "canadacentral"
}

variable "tags" {
  description = "Common tags applied to all resources in this stack."
  type        = map(string)
  default     = {}
}
