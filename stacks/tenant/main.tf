module "platform_rg" {
  source = "../../modules/tenant-platform-rg"

  ministry_code        = var.ministry_code
  tenant_name          = var.tenant_name
  tenant_program_name  = var.tenant_program_name
  environment          = var.environment
  location             = var.location
  tags                 = var.tags
}

module "key_vault" {
  source = "../../modules/key-vault"

  name                = "kv-${var.ministry_code}-${local.tenant_segment}-${var.environment}"
  resource_group_name = module.platform_rg.name
  location            = var.location
  tenant_id           = var.azure_tenant_id
  sku_name            = var.key_vault_sku
  rbac_assignments    = var.kv_rbac_assignments
  tags                = var.tags
}

module "key_vault_private_endpoint" {
  source = "../../modules/private-endpoint"

  name                 = "pe-kv-${var.ministry_code}-${local.tenant_segment}-${var.environment}"
  resource_group_name  = module.platform_rg.name
  location             = var.location
  subnet_id            = var.pe_subnet_id
  target_resource_id   = module.key_vault.id
  subresource_names    = ["vault"]
  private_dns_zone_ids = var.private_dns_zone_ids
  tags                 = var.tags
}

module "workspace_rg" {
  source = "../../modules/workspace-rg"

  ministry_code                     = var.ministry_code
  tenant_name                       = var.tenant_name
  tenant_program_name               = var.tenant_program_name
  environment                       = var.environment
  location                          = var.location
  workspace_owners_group_object_id  = var.workspace_owners_group_object_id
  tags                               = var.tags
}

# Grants tenant team members Virtual Machine User Login on the shared jumpbox so
# they can open a Bastion tunnel to reach private endpoints (Key Vault, storage,
# Fabric). The jumpbox VM itself is managed in bcgov/eo-dmi-alz-bastion-jumpbox;
# this assignment is the only cross-repo resource in the tenant stack.
#
# TEMPORARILY COMMENTED OUT: requires the dev/test/prod UAMIs to have
# Role Based Access Control Administrator on the jumpbox VM (tools subscription).
# Re-enable once stacks/bootstrap/identity has been re-applied with the
# jumpbox_rbac_admin role assignments.
#
# resource "azurerm_role_assignment" "jumpbox_vm_login" {
#   scope                = var.jumpbox_vm_id
#   role_definition_name = "Virtual Machine User Login"
#   principal_id         = var.workspace_owners_group_object_id
# }

module "dedicated_fabric_capacity" {
  count = var.create_dedicated_capacity ? 1 : 0

  source = "../../modules/fabric-capacity"

  # Fabric capacity names allow lowercase alphanumeric only (no hyphens).
  name                   = replace("fc${var.ministry_code}${local.tenant_segment}${var.environment}", "-", "")
  resource_group_name   = module.platform_rg.name
  location               = var.location
  sku_name               = var.dedicated_capacity_sku
  administrator_members = var.fabric_capacity_admins
  tags                   = var.tags
}
