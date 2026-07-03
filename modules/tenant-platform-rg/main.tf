locals {
  # Naming convention: resource-ministry-tenant-tenant_program-environment,
  # where tenant_name occupies the "program" position and tenant_program_name
  # is an optional additional segment. See docs/platform-guide.md "Naming
  # conventions" for the full standard and rationale.
  tenant_segment = var.tenant_program_name != null && var.tenant_program_name != "" ? "${var.tenant_name}-${var.tenant_program_name}" : var.tenant_name
}

resource "azurerm_resource_group" "platform" {
  name     = "rg-${var.ministry_code}-${local.tenant_segment}-${var.environment}"
  location = var.location

  tags = merge(var.tags, {
    "managed-by" = "terraform"
    "purpose"    = "platform"
  })
}
