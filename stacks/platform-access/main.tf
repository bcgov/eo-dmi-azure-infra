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

# Reader on the Bastion host is required for `az network bastion ssh` to query
# the Bastion's DNS name before opening the tunnel. Without it users get
# AuthorizationFailed on Microsoft.Network/bastionHosts/read.
resource "azurerm_role_assignment" "bastion_reader" {
  for_each = toset(var.jumpbox_principal_ids)

  scope                = var.bastion_id
  role_definition_name = "Reader"
  principal_id         = each.value
}
