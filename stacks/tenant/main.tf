module "platform_rg" {
  source = "../../modules/tenant-platform-rg"

  ministry_code       = var.ministry_code
  tenant_name         = var.tenant_name
  tenant_program_name = var.tenant_program_name
  environment         = var.environment
  location            = var.location
  tags                = local.all_tags
}

module "key_vault" {
  count = var.create_key_vault ? 1 : 0

  source = "../../modules/key-vault"

  name                = "kv-${var.ministry_code}-${local.tenant_segment}-${var.environment}"
  resource_group_name = module.platform_rg.name
  location            = var.location
  tenant_id           = var.azure_tenant_id
  sku_name            = var.key_vault_sku
  rbac_assignments    = var.kv_rbac_assignments
  tags                = local.all_tags
}

module "key_vault_private_endpoint" {
  count = var.create_key_vault ? 1 : 0

  source = "../../modules/private-endpoint"

  name                 = "pe-kv-${var.ministry_code}-${local.tenant_segment}-${var.environment}"
  resource_group_name  = module.platform_rg.name
  location             = var.location
  subnet_id            = var.pe_subnet_id
  target_resource_id   = module.key_vault[0].id
  subresource_names    = ["vault"]
  private_dns_zone_ids = var.private_dns_zone_ids
  tags                 = local.all_tags
}

# Adding count above moved these modules from module.key_vault to
# module.key_vault[0] in state. Without these blocks every existing tenant's
# plan would destroy and recreate its vault and private endpoint. Keep them
# permanently - they are free, and any state not yet migrated still needs them.
moved {
  from = module.key_vault
  to   = module.key_vault[0]
}

moved {
  from = module.key_vault_private_endpoint
  to   = module.key_vault_private_endpoint[0]
}

module "dedicated_fabric_capacity" {
  count = var.create_dedicated_capacity ? 1 : 0

  source = "../../modules/fabric-capacity"

  # Fabric capacity names allow lowercase alphanumeric only (no hyphens).
  name                  = replace("fc${var.ministry_code}${local.tenant_segment}${var.environment}", "-", "")
  resource_group_name   = module.platform_rg.name
  location              = var.location
  sku_name              = var.dedicated_capacity_sku
  administrator_members = var.fabric_capacity_admins
  tags                  = local.all_tags
}
