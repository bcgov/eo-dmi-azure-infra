variable "name" {
  description = "Name of the private endpoint."
  type        = string
}

variable "resource_group_name" {
  description = "Resource group the private endpoint is deployed into."
  type        = string
}

variable "location" {
  description = "Azure region for the private endpoint."
  type        = string
  default     = "canadacentral"
}

variable "subnet_id" {
  description = "Resource ID of the existing shared PE subnet for this environment (see params/global/network-reference.yaml). The subnet itself is not managed by this repo."
  type        = string
}

variable "target_resource_id" {
  description = "Resource ID of the PaaS resource the private endpoint connects to (e.g. a Key Vault)."
  type        = string
}

variable "subresource_names" {
  description = "Private link sub-resource group IDs, e.g. [\"vault\"] for Key Vault."
  type        = list(string)
}

variable "private_dns_zone_ids" {
  description = <<-EOT
    Optional private DNS zone IDs to register this private endpoint in.
    Leave empty if ALZ policy (Azure Policy DINE) auto-registers private
    endpoints in the correct privatelink zone for this subscription -
    confirm with the platform team before populating this.
  EOT
  type    = list(string)
  default = []
}

variable "tags" {
  description = "Common tags applied to the private endpoint."
  type        = map(string)
  default     = {}
}
