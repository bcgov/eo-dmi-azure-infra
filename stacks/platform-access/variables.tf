variable "subscription_id" {
  description = "Subscription ID for b9cee3-tools (where the jumpbox VM lives)."
  type        = string
}

variable "jumpbox_vm_id" {
  description = "Resource ID of the shared Bastion jumpbox VM."
  type        = string
}

variable "bastion_id" {
  description = "Resource ID of the shared Azure Bastion host. Used to derive the Bastion's resource group, which is what Reader is granted on - see the comment in main.tf on why the grant is not scoped to the host itself."
  type        = string
}

variable "jumpbox_principal_ids" {
  description = "Entra ID object IDs (users or groups) to grant Virtual Machine User Login on the shared jumpbox. Anyone who needs to open a Bastion tunnel to reach tenant private endpoints must be listed here."
  type        = list(string)
  default     = []
}
