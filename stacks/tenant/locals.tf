locals {
  # Naming convention: resource-ministry-tenant-tenant_program-environment
  # for this tenant's own resources (NOT the platform-wide ministry-program
  # convention used below for the remote-state lookup). See
  # docs/platform-guide.md "Naming conventions".
  tenant_segment = var.tenant_program_name != null && var.tenant_program_name != "" ? "${var.tenant_name}-${var.tenant_program_name}" : var.tenant_name

  # try(...) falls back to {} when params/global/fabric-capacities.yaml has
  # no active "capacities:" key (e.g. capacities intentionally disabled for
  # now) - yamldecode of an all-comment/empty document returns null, and
  # null.capacities would otherwise error.
  capacity_registry = try(yamldecode(file("${path.module}/../../params/global/fabric-capacities.yaml")).capacities, {})

  fabric_capacity_home_env = (
    !var.create_dedicated_capacity && var.fabric_capacity_name != null
    ? local.capacity_registry[var.fabric_capacity_name].home_env
    : null
  )

  shared_capacity_id = (
    local.fabric_capacity_home_env != null
    ? data.terraform_remote_state.shared[0].outputs.shared_capacity_ids[var.fabric_capacity_name]
    : null
  )
}

# Reads stacks/shared's state for the environment that hosts this tenant's
# shared Fabric capacity. Requires the calling UAMI to have at least
# "Storage Blob Data Reader" on that environment's state storage account -
# see stacks/bootstrap/identity (every UAMI is granted this on the tools
# state storage account, since the default shared-cross-env capacity is
# homed there). Naming must match stacks/bootstrap/state-backend - see
# docs/platform-guide.md "Naming conventions".
data "terraform_remote_state" "shared" {
  count = local.fabric_capacity_home_env != null ? 1 : 0

  backend = "azurerm"
  config = {
    resource_group_name  = "rg-${var.ministry_code}-${var.program_code}-tfstate-${local.fabric_capacity_home_env}"
    storage_account_name = "st${var.ministry_code}${var.program_code}${local.fabric_capacity_home_env}tfstate"
    container_name       = "tfstate"
    key                  = "shared/${local.fabric_capacity_home_env}.tfstate"
    use_azuread_auth     = true
  }
}
