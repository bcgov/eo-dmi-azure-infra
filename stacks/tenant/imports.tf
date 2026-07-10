# One-time import of pre-existing tenant resources into Terraform state.
# These were created before Terraform management was in place.
#
# Gated on var.import_preexisting_resources (default false), so new tenants
# added in the future are unaffected — these imports are no-ops unless the
# tenant's tfvars explicitly sets import_preexisting_resources = true.
#
# Remove this file (and the import_preexisting_resources = true line from
# the relevant tfvars) after a successful apply has imported all resources.

import {
  for_each = var.import_preexisting_resources ? toset(["this"]) : toset([])
  to       = module.platform_rg.azurerm_resource_group.platform
  id       = "/subscriptions/${var.subscription_id}/resourceGroups/rg-${var.ministry_code}-${local.tenant_segment}-${var.environment}"
}

import {
  for_each = var.import_preexisting_resources ? toset(["this"]) : toset([])
  to       = module.workspace_rg.azurerm_resource_group.workspace
  id       = "/subscriptions/${var.subscription_id}/resourceGroups/rg-${var.ministry_code}-${local.tenant_segment}-${var.environment}-ws"
}

import {
  for_each = var.import_preexisting_resources ? toset(["this"]) : toset([])
  to       = module.key_vault.azurerm_key_vault.this
  id       = "/subscriptions/${var.subscription_id}/resourceGroups/rg-${var.ministry_code}-${local.tenant_segment}-${var.environment}/providers/Microsoft.KeyVault/vaults/kv-${var.ministry_code}-${local.tenant_segment}-${var.environment}"
}

import {
  for_each = var.import_preexisting_resources ? toset(["this"]) : toset([])
  to       = module.key_vault_private_endpoint.azurerm_private_endpoint.this
  id       = "/subscriptions/${var.subscription_id}/resourceGroups/rg-${var.ministry_code}-${local.tenant_segment}-${var.environment}/providers/Microsoft.Network/privateEndpoints/pe-kv-${var.ministry_code}-${local.tenant_segment}-${var.environment}"
}
