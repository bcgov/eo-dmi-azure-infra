variable "ministry_code" {
  description = "Short BC Gov ministry code used in resource naming (e.g. \"citz\"). See docs/platform-guide.md \"Naming conventions\"."
  type        = string
}

variable "program_code" {
  description = "Short program code for the Fabric platform itself (e.g. \"pmt\"). NOT used in this tenant's own resource names (see tenant_name/tenant_program_name) - only used to locate stacks/shared's remote state, which is named per the platform-wide ministry/program convention. Must match the value used by stacks/shared and stacks/bootstrap/*."
  type        = string
}

variable "tenant_name" {
  description = "Short tenant identifier (e.g. \"pmt\"). Occupies the \"program\" position for this tenant's own resource names - see docs/platform-guide.md \"Naming conventions\"."
  type        = string
}

variable "tenant_program_name" {
  description = "Optional sub-program identifier for this tenant, used as an additional naming segment (e.g. \"pdt\"). Omit (leave null) if the tenant has no sub-programs."
  type        = string
  default     = null
}

variable "environment" {
  description = "Environment short name this tenant instance is deployed into."
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
  description = "Azure region for tenant resources."
  type        = string
  default     = "canadacentral"
}

variable "azure_tenant_id" {
  description = "Entra ID (Azure AD) tenant ID used for Key Vault RBAC authorization."
  type        = string
}

# --- Networking (existing - see params/global/network-reference.yaml) ------

variable "pe_subnet_id" {
  description = "Resource ID of the existing shared PE subnet for this environment's spoke."
  type        = string
}

variable "private_dns_zone_ids" {
  description = "Optional private DNS zone IDs for privatelink.vaultcore.azure.net. Leave empty if ALZ policy auto-registers private endpoints."
  type        = list(string)
  default     = []
}

# --- Key Vault ---------------------------------------------------------------

variable "key_vault_sku" {
  description = "Key Vault SKU."
  type        = string
  default     = "standard"
}

variable "kv_rbac_assignments" {
  description = "Role assignments to grant on the tenant's Key Vault, e.g. the tenant team getting \"Key Vault Administrator\"."
  type = list(object({
    role_definition_name = string
    principal_id         = string
  }))
  default = []
}

# --- Workspace (self-service) RG ---------------------------------------------

variable "workspace_owners_group_object_id" {
  description = "Entra ID object ID of the group that self-manages resources in this tenant's workspace RG."
  type        = string
}

# --- Fabric capacity -----------------------------------------------------------

variable "create_dedicated_capacity" {
  description = "Whether to create a Fabric capacity dedicated to this tenant/environment. If false, the tenant uses the shared capacity named by fabric_capacity_name (see locals.tf)."
  type        = bool
  default     = false
}

variable "dedicated_capacity_sku" {
  description = "Fabric capacity SKU when create_dedicated_capacity is true, e.g. \"F2\", \"F4\"."
  type        = string
  default     = "F2"
}

variable "fabric_capacity_admins" {
  description = "UPNs or object IDs of Fabric capacity administrators, when create_dedicated_capacity is true."
  type        = list(string)
  default     = []
}

variable "fabric_capacity_name" {
  description = "Name of the shared capacity from params/global/fabric-capacities.yaml this tenant uses, when create_dedicated_capacity is false. Its resource ID is resolved via remote state - see locals.tf."
  type        = string
  default     = null
}

variable "jumpbox_vm_id" {
  description = "Resource ID of the shared Bastion jumpbox VM (in bcgov/eo-dmi-alz-bastion-jumpbox). The tenant's Entra ID group (workspace_owners_group_object_id) is granted Virtual Machine User Login on this VM so tenant teams can reach private endpoints via the Bastion tunnel."
  type        = string
}

variable "tags" {
  description = "Common tags applied to all resources in this stack."
  type        = map(string)
  default     = {}
}

# --- One-time import ---------------------------------------------------------

variable "import_preexisting_resources" {
  description = "Set to true to import pre-existing Azure resources into Terraform state. Only needed for tenants whose resources were created before Terraform management was in place. Remove after a successful apply has imported all resources."
  type        = bool
  default     = false
}
