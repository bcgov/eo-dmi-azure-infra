resource "azurerm_resource_group" "shared" {
  count = length(local.shared_capacities) > 0 ? 1 : 0

  # Naming convention: resource-ministry-program-subprogram-environment,
  # with "shared" as the subprogram segment. See docs/platform-guide.md
  # "Naming conventions".
  name     = "rg-${var.ministry_code}-${var.program_code}-shared-${var.environment}"
  location = var.location

  tags = merge(var.tags, { "managed-by" = "terraform" })
}

module "fabric_capacity" {
  for_each = local.shared_capacities

  source = "../../modules/fabric-capacity"

  # each.key is the logical capacity name from params/global/fabric-capacities.yaml
  # (e.g. "shared-cross-env") - the Azure resource name strips hyphens since Fabric
  # capacity names allow lowercase alphanumeric only (no hyphens).
  name                   = replace("fc${var.ministry_code}${var.program_code}${each.key}", "-", "")
  resource_group_name   = azurerm_resource_group.shared[0].name
  location               = var.location
  sku_name               = each.value.sku
  administrator_members = each.value.administrator_members
  tags                   = var.tags
}
