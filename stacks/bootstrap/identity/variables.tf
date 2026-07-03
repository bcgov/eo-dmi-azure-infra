variable "ministry_code" {
  description = "Short BC Gov ministry code used in resource naming (e.g. \"citz\"). See docs/platform-guide.md \"Naming conventions\". Must match stacks/bootstrap/state-backend's value for each environment - this stack computes the same state storage account names to grant RBAC on them."
  type        = string
}

variable "program_code" {
  description = "Short program code used in resource naming (e.g. \"pmt\"). Must match stacks/bootstrap/state-backend's value."
  type        = string
}

variable "subscription_ids" {
  description = "Subscription IDs for each environment in the b9cee3 project set."
  type = object({
    tools = string
    dev   = string
    test  = string
    prod  = string
  })
}

variable "location" {
  description = "Azure region for the platform identity resource group."
  type        = string
  default     = "canadacentral"
}

variable "github_org" {
  description = "GitHub organization that owns this repository."
  type        = string
  default     = "bcgov"
}

variable "github_repo" {
  description = "Name of this repository (used in federated credential subjects)."
  type        = string
  default     = "eo-dmi-azure-infra"
}

variable "bastion_resource_id" {
  description = "Resource ID of the existing Bastion host in b9cee3-tools (bcgov/eo-dmi-alz-bastion-jumpbox)."
  type        = string
}

variable "jumpbox_vm_resource_id" {
  description = "Resource ID of the existing jumpbox VM in b9cee3-tools (bcgov/eo-dmi-alz-bastion-jumpbox), used by CI to open a Bastion tunnel."
  type        = string
}

variable "tags" {
  description = "Common tags applied to all resources in this stack."
  type        = map(string)
  default     = {}
}
