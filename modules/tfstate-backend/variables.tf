variable "resource_group_name" {
  description = "Name of the resource group created to hold the Terraform state storage account."
  type        = string
}

variable "location" {
  description = "Azure region for the state storage account."
  type        = string
  default     = "canadacentral"
}

variable "storage_account_name" {
  description = "Globally unique storage account name (lowercase alphanumeric, <= 24 chars)."
  type        = string
}

variable "account_replication_type" {
  description = "Storage account replication type."
  type        = string
  default     = "GRS"
}

variable "subnet_id" {
  description = "Resource ID of the existing shared PE subnet for this subscription (see params/global/network-reference.yaml)."
  type        = string
}

variable "private_dns_zone_ids" {
  description = "Optional private DNS zone IDs for privatelink.blob.core.windows.net. Leave empty if ALZ policy auto-registers private endpoints."
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Common tags applied to all resources in this module."
  type        = map(string)
  default     = {}
}
