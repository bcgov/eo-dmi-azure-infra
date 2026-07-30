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
