variable "ministry_code" {
  description = "Short BC Gov ministry code used in resource naming (e.g. \"citz\")."
  type        = string
}

variable "tenant_name" {
  description = "Short tenant identifier used in resource naming (e.g. \"pmt\"). Occupies the \"program\" position for tenant-owned resources - see docs/platform-guide.md \"Naming conventions\"."
  type        = string
}

variable "tenant_program_name" {
  description = "Optional sub-program identifier for this tenant, used as an additional naming segment (e.g. \"pdt\"). Omit (leave null) if the tenant has no sub-programs."
  type        = string
  default     = null
}

variable "environment" {
  description = "Environment short name."
  type        = string

  validation {
    condition     = contains(["tools", "dev", "test", "prod"], var.environment)
    error_message = "environment must be one of: tools, dev, test, prod."
  }
}

variable "location" {
  description = "Azure region for the resource group."
  type        = string
  default     = "canadacentral"
}

variable "tags" {
  description = "Common tags applied to the resource group."
  type        = map(string)
  default     = {}
}
