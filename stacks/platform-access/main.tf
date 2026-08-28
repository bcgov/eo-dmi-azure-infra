# Platform-wide Bastion jumpbox access.
#
# Grants Virtual Machine User Login on the shared jumpbox VM to every principal
# in jumpbox_principal_ids. This is managed once here rather than per-tenant so
# that adding/removing a user never requires touching individual tenant stacks,
# and so the same person appearing in multiple tenants doesn't cause a 409
# RoleAssignmentExists conflict.
#
# To grant a new user Bastion access: add their object ID to
# params/global/platform-access.tfvars and open a PR. No tenant stack changes needed.

resource "azurerm_role_assignment" "jumpbox_vm_login" {
  for_each = toset(var.jumpbox_principal_ids)

  scope                = var.jumpbox_vm_id
  role_definition_name = "Virtual Machine User Login"
  principal_id         = each.value
}

locals {
  # The Bastion's resource group, derived from bastion_id rather than taken as
  # its own variable so the two can never drift apart.
  bastion_rg_id = regex("^(/subscriptions/[^/]+/resourceGroups/[^/]+)", var.bastion_id)[0]
}

# Reader is required for `az network bastion ssh` to query the Bastion's DNS
# name before opening the tunnel. Without it users get AuthorizationFailed on
# Microsoft.Network/bastionHosts/read.
#
# Scoped to the Bastion's RESOURCE GROUP, not the Bastion host itself. Azure
# Bastion has no stop/deallocate, so the host is deleted nightly to avoid
# charges and recreated by the Create-BastionHost runbook. A recreated host is a
# new resource, and role assignments scoped to a resource are destroyed with it
# - so host-scoped grants silently vanish every night. The resource group
# persists, and Reader on it still confers bastionHosts/read by inheritance.
#
# This also covers the virtualMachines/read and networkInterfaces/read that
# Microsoft's Bastion docs list as prerequisites, since the jumpbox VM and its
# NIC live in the same resource group.
resource "azurerm_role_assignment" "bastion_reader" {
  for_each = toset(var.jumpbox_principal_ids)

  scope                = local.bastion_rg_id
  role_definition_name = "Reader"
  principal_id         = each.value
}
