variable "ministry_code" {
  description = "Short BC Gov ministry code used in resource naming (e.g. \"citz\"). See docs/platform-guide.md \"Naming conventions\". Must match stacks/bootstrap/identity's value - both compute the same state storage account name."
  type        = string
}

variable "program_code" {
  description = "Short program code used in resource naming (e.g. \"pmt\"). Must match stacks/bootstrap/identity's value."
  type        = string
}

variable "environment" {
  description = "Subscription short name: tools, dev, test, or prod."
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
  description = "Azure region for the state storage account."
  type        = string
  default     = "canadacentral"
}

variable "subnet_id" {
  description = "Resource ID of the existing shared PE subnet in this subscription's spoke (see params/global/network-reference.yaml)."
  type        = string
}

variable "private_dns_zone_ids" {
  description = "Optional private DNS zone IDs for privatelink.blob.core.windows.net. Leave empty if ALZ policy auto-registers private endpoints."
  type        = list(string)
  default     = []
}

variable "account_replication_type" {
  description = "Storage account replication type for the state storage account."
  type        = string
  default     = "GRS"
}

variable "tags" {
  description = "Common tags applied to all resources in this stack."
  type        = map(string)
  default     = {}
}
