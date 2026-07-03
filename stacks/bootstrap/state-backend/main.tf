locals {
  # Naming convention: resource-ministry-program-subprogram-environment,
  # with "tfstate" as the subprogram segment. Shared with
  # stacks/bootstrap/identity, which references these same names to grant
  # the per-subscription UAMI access to its state storage account without a
  # remote-state lookup. See docs/platform-guide.md "Naming conventions".
  #
  # Storage account names allow lowercase alphanumeric only (no hyphens),
  # max 24 chars - keep ministry_code/program_code short (<=4 chars
  # recommended) so this fits across all environments, e.g. "tools" (5 chars).
  resource_group_name  = "rg-${var.ministry_code}-${var.program_code}-tfstate-${var.environment}"
  storage_account_name = "st${var.ministry_code}${var.program_code}${var.environment}tfstate"
}

module "tfstate_backend" {
  source = "../../../modules/tfstate-backend"

  resource_group_name      = local.resource_group_name
  storage_account_name     = local.storage_account_name
  location                  = var.location
  account_replication_type = var.account_replication_type
  subnet_id                 = var.subnet_id
  private_dns_zone_ids      = var.private_dns_zone_ids
  tags                       = var.tags
}
