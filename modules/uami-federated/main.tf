resource "azurerm_user_assigned_identity" "this" {
  name                = var.name
  resource_group_name = var.resource_group_name
  location            = var.location

  tags = merge(var.tags, { "managed-by" = "terraform" })
}

resource "azurerm_federated_identity_credential" "this" {
  for_each = { for fc in var.federated_credentials : fc.name => fc }

  name                = each.value.name
  resource_group_name = var.resource_group_name
  parent_id           = azurerm_user_assigned_identity.this.id

  issuer  = "https://token.actions.githubusercontent.com"
  subject = each.value.subject
  audience = ["api://AzureADTokenExchange"]
}
