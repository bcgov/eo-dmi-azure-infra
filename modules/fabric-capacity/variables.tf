variable "name" {
  description = "Name of the Fabric capacity resource."
  type        = string
}

variable "resource_group_name" {
  description = "Resource group the capacity is deployed into."
  type        = string
}

variable "location" {
  description = "Azure region for the capacity."
  type        = string
  default     = "canadacentral"
}

variable "sku_name" {
  description = "Fabric capacity SKU, e.g. \"F2\", \"F4\", \"F8\"."
  type        = string
}

variable "administrator_members" {
  description = "UPNs or object IDs of Fabric capacity administrators (Entra ID users or groups)."
  type        = list(string)
}

variable "tags" {
  description = "Common tags applied to the capacity."
  type        = map(string)
  default     = {}
}
