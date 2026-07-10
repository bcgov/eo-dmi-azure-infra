# One-time import of pre-existing shared resources into Terraform state.
# These were created before Terraform management was in place.
#
# The for_each expressions mirror the count/for_each on the target resources,
# so these imports are no-ops for environments with no shared capacities
# (dev, test, prod) and only fire for tools where shared-cross-env lives.
#
# Remove this file after a successful apply has imported all resources.

import {
  for_each = length(local.shared_capacities) > 0 ? toset(["this"]) : toset([])
  to       = azurerm_resource_group.shared[0]
  id       = "/subscriptions/${var.subscription_id}/resourceGroups/rg-${var.ministry_code}-${var.program_code}-shared-${var.environment}"
}

import {
  for_each = local.shared_capacities
  to       = module.fabric_capacity[each.key].azurerm_fabric_capacity.this
  id       = "/subscriptions/${var.subscription_id}/resourceGroups/rg-${var.ministry_code}-${var.program_code}-shared-${var.environment}/providers/Microsoft.Fabric/capacities/${replace("fc${var.ministry_code}${var.program_code}${each.key}", "-", "")}"
}
