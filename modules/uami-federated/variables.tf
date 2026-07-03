variable "name" {
  description = "Name of the user-assigned managed identity."
  type        = string
}

variable "resource_group_name" {
  description = "Resource group the identity is created in (the platform identity RG in b9cee3-tools)."
  type        = string
}

variable "location" {
  description = "Azure region for the identity."
  type        = string
  default     = "canadacentral"
}

variable "federated_credentials" {
  description = <<-EOT
    GitHub OIDC federated credentials to attach to this identity. Each entry's
    `subject` must match a GitHub OIDC token claim, e.g.:
      "repo:bcgov/eo-dmi-azure-infra:environment:dev"
      "repo:bcgov/eo-dmi-azure-infra:ref:refs/heads/main"
  EOT
  type = list(object({
    name    = string
    subject = string
  }))
}

variable "tags" {
  description = "Common tags applied to the identity."
  type        = map(string)
  default     = {}
}
