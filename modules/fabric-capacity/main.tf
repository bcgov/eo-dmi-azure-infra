# Requires azurerm provider version with azurerm_fabric_capacity support
# (verify against the pinned provider version in each stack's providers.tf -
# fall back to an azapi_resource for Microsoft.Fabric/capacities if the
# resource is not yet available in the pinned azurerm release).
resource "azurerm_fabric_capacity" "this" {
  name                = var.name
  resource_group_name = var.resource_group_name
  location            = var.location

  administration_members = var.administrator_members

  sku {
    name = var.sku_name
    tier = "Fabric"
  }

  tags = merge(var.tags, { "managed-by" = "terraform" })
}
