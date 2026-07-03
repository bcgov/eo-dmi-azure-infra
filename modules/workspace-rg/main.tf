locals {
  # Naming convention: resource-ministry-tenant-tenant_program-environment,
  # with a "-ws" suffix to distinguish this from the tenant's platform RG
  # (which shares the same ministry/tenant/tenant_program/environment
  # segments). See docs/platform-guide.md "Naming conventions".
  tenant_segment = var.tenant_program_name != null && var.tenant_program_name != "" ? "${var.tenant_name}-${var.tenant_program_name}" : var.tenant_name
}

resource "azurerm_resource_group" "workspace" {
  name     = "rg-${var.ministry_code}-${local.tenant_segment}-${var.environment}-ws"
  location = var.location

  tags = merge(var.tags, {
    "managed-by" = "terraform"
    "purpose"    = "self-service"
  })
}

# Contents of this RG are intentionally never modeled in Terraform beyond
# this point - tenant teams create/manage their own resources here.

# Grants the tenant's Entra group the configured role (default: Contributor)
# on this RG. Contributor allows the tenant team to create, update, and delete
# any Azure resource inside the workspace RG - for example, deploying their own
# pipelines, storage accounts, or compute. It does NOT allow them to assign
# roles to others (that requires Owner or User Access Administrator, which is
# intentionally not granted here).
#
# To add or remove people from this access:
#   - Add/remove them from the Entra group whose object ID is in
#     workspace_owners_group_object_id (params/<env>/tenants/<tenant>/tenant.tfvars).
#   - No Terraform changes are needed for membership changes - Terraform only
#     manages the role assignment on the group, not who is in the group.
#
# To change what the group is allowed to do (e.g. read-only instead of
# Contributor), set role_definition_name in the stacks/tenant module call.
resource "azurerm_role_assignment" "owners" {
  scope                = azurerm_resource_group.workspace.id
  role_definition_name = var.role_definition_name
  principal_id         = var.workspace_owners_group_object_id
}
