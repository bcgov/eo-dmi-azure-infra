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
  description = "UPNs of Fabric capacity administrators, e.g. \"first.last@gov.bc.ca\". Use UPNs, NOT object IDs - Microsoft.Fabric rejects a raw user object ID with \"400 BadRequest: All provided principals must be existing, user or service principals\". This differs from the rest of this repo, where object IDs are preferred because UPNs change when users are renamed. Service principals are identified by their application ID. Must be non-empty: properties.administration.members is required by the ARM API."
  type        = list(string)

  validation {
    condition     = length(var.administrator_members) > 0
    error_message = "administrator_members must contain at least one principal - the Fabric API requires properties.administration.members."
  }
}

variable "tags" {
  description = "Common tags applied to the capacity."
  type        = map(string)
  default     = {}
}
