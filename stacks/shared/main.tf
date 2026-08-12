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
  #
  # The default fc<ministry_code><program_code><key> reads as a platform-wide
  # capacity. An entry that belongs to a single tenant (e.g. one capacity shared
  # between that tenant's dev and test) can set name_override in the registry to
  # name itself after the tenant instead. Entries without name_override are
  # unaffected - the expression below is unchanged for them.
  #
  # Capacity "name" is ForceNew: changing it destroys and recreates the capacity.
  # Never edit or remove an existing entry's name_override.
  name                  = try(each.value.name_override, replace("fc${var.ministry_code}${var.program_code}${each.key}", "-", ""))
  resource_group_name   = azurerm_resource_group.shared[0].name
  location              = var.location
  sku_name              = each.value.sku
  administrator_members = each.value.administrator_members

  # Platform-wide tags from params/<env>/shared.tfvars, plus optional per-entry
  # tags from the registry. A capacity created here is not owned by any tenant
  # stack, so it gets no tenant tag automatically the way stacks/tenant
  # resources do - set tags.tenant in the registry entry for any capacity that
  # belongs to one tenant, or cost reports grouped by tenant will miss it.
  tags = merge(var.tags, try(each.value.tags, {}))
}
