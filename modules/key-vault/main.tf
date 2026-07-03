resource "azurerm_key_vault" "this" {
  name                = var.name
  resource_group_name = var.resource_group_name
  location            = var.location
  tenant_id           = var.tenant_id
  sku_name            = var.sku_name

  rbac_authorization_enabled = true

  public_network_access_enabled = false
  network_acls {
    default_action = "Deny"
    bypass         = "AzureServices"
  }

  purge_protection_enabled   = var.purge_protection_enabled
  soft_delete_retention_days = var.soft_delete_retention_days

  tags = merge(var.tags, { "managed-by" = "terraform" })
}

resource "azurerm_role_assignment" "rbac" {
  for_each = { for ra in var.rbac_assignments : "${ra.role_definition_name}-${ra.principal_id}" => ra }

  scope                = azurerm_key_vault.this.id
  role_definition_name = each.value.role_definition_name
  principal_id         = each.value.principal_id
}
