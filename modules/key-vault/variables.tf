variable "name" {
  description = "Name of the Key Vault. Must be globally unique across Azure."
  type        = string
}

variable "resource_group_name" {
  description = "Resource group the Key Vault is deployed into (the tenant's platform RG)."
  type        = string
}

variable "location" {
  description = "Azure region for the Key Vault."
  type        = string
  default     = "canadacentral"
}

variable "tenant_id" {
  description = "Entra ID (Azure AD) tenant ID used for RBAC authorization."
  type        = string
}

variable "sku_name" {
  description = "Key Vault SKU."
  type        = string
  default     = "standard"

  validation {
    condition     = contains(["standard", "premium"], var.sku_name)
    error_message = "sku_name must be \"standard\" or \"premium\"."
  }
}

variable "purge_protection_enabled" {
  description = "Whether purge protection is enabled. Recommended true for all environments."
  type        = bool
  default     = true
}

variable "soft_delete_retention_days" {
  description = "Soft-delete retention period in days (7-90)."
  type        = number
  default     = 90
}

variable "rbac_assignments" {
  description = "Role assignments to grant on this Key Vault, e.g. tenant admins getting \"Key Vault Administrator\"."
  type = list(object({
    role_definition_name = string
    principal_id         = string
  }))
  default = []
}

variable "tags" {
  description = "Common tags applied to the Key Vault."
  type        = map(string)
  default     = {}
}
