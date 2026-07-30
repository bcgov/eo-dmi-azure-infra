variable "subscription_id" {
  description = "Subscription ID for b9cee3-tools (where the jumpbox VM lives)."
  type        = string
}

variable "jumpbox_vm_id" {
  description = "Resource ID of the shared Bastion jumpbox VM."
  type        = string
}

variable "jumpbox_principal_ids" {
  description = "Entra ID object IDs (users or groups) to grant Virtual Machine User Login on the shared jumpbox. Anyone who needs to open a Bastion tunnel to reach tenant private endpoints must be listed here."
  type        = list(string)
  default     = []
}
