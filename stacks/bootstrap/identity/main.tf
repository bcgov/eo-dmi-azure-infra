locals {
  environments = ["tools", "dev", "test", "prod"]

  # Must match the naming convention in stacks/bootstrap/state-backend.
  tfstate_resource_group_name = {
    for env in local.environments : env => "rg-${var.ministry_code}-${var.program_code}-tfstate-${env}"
  }
  tfstate_storage_account_name = {
    for env in local.environments : env => "st${var.ministry_code}${var.program_code}${env}tfstate"
  }

  # Roles each UAMI needs on its own subscription to run the tenant/shared
  # stacks (manage resources + grant tenant RBAC).
  own_subscription_roles = [
    "Contributor",
    "Role Based Access Control Administrator",
  ]
}

resource "azurerm_resource_group" "identity" {
  # Naming convention: resource-ministry-program-subprogram-environment,
  # with "identity" as the subprogram segment and no environment segment
  # (this RG is global, not per-environment). See
  # docs/platform-guide.md "Naming conventions".
  name     = "rg-${var.ministry_code}-${var.program_code}-identity"
  location = var.location

  tags = merge(var.tags, { "managed-by" = "terraform" })
}

# ---------------------------------------------------------------------------
# One UAMI per subscription, all homed in b9cee3-tools for central management.
# ---------------------------------------------------------------------------
module "uami" {
  for_each = toset(local.environments)

  source = "../../../modules/uami-federated"

  name                = "uami-${var.ministry_code}-${var.program_code}-${each.key}"
  resource_group_name = azurerm_resource_group.identity.name
  location            = var.location
  tags                = var.tags

  federated_credentials = [
    {
      name    = "github-environment-${each.key}"
      subject = "repo:${var.github_org}/${var.github_repo}:environment:${each.key}"
    },
    {
      name    = "github-ref-main"
      subject = "repo:${var.github_org}/${var.github_repo}:ref:refs/heads/main"
    },
    {
      name    = "github-pull-request"
      subject = "repo:${var.github_org}/${var.github_repo}:pull_request"
    },
  ]
}

# ---------------------------------------------------------------------------
# Own-subscription RBAC: each UAMI manages resources and grants tenant RBAC
# inside its own subscription only.
# ---------------------------------------------------------------------------
resource "azurerm_role_assignment" "tools_subscription" {
  for_each = toset(local.own_subscription_roles)

  scope                = "/subscriptions/${var.subscription_ids.tools}"
  role_definition_name = each.value
  principal_id         = module.uami["tools"].principal_id
}

resource "azurerm_role_assignment" "dev_subscription" {
  for_each = toset(local.own_subscription_roles)

  provider = azurerm.dev

  scope                = "/subscriptions/${var.subscription_ids.dev}"
  role_definition_name = each.value
  principal_id         = module.uami["dev"].principal_id
}

resource "azurerm_role_assignment" "test_subscription" {
  for_each = toset(local.own_subscription_roles)

  provider = azurerm.test

  scope                = "/subscriptions/${var.subscription_ids.test}"
  role_definition_name = each.value
  principal_id         = module.uami["test"].principal_id
}

resource "azurerm_role_assignment" "prod_subscription" {
  for_each = toset(local.own_subscription_roles)

  provider = azurerm.prod

  scope                = "/subscriptions/${var.subscription_ids.prod}"
  role_definition_name = each.value
  principal_id         = module.uami["prod"].principal_id
}

# ---------------------------------------------------------------------------
# State backend access: each UAMI gets Storage Blob Data Contributor on its
# own subscription's state storage account (azuread-authenticated backend).
# ---------------------------------------------------------------------------
resource "azurerm_role_assignment" "tools_state_storage" {
  scope                = "/subscriptions/${var.subscription_ids.tools}/resourceGroups/${local.tfstate_resource_group_name["tools"]}/providers/Microsoft.Storage/storageAccounts/${local.tfstate_storage_account_name["tools"]}"
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = module.uami["tools"].principal_id
}

resource "azurerm_role_assignment" "dev_state_storage" {
  provider = azurerm.dev

  scope                = "/subscriptions/${var.subscription_ids.dev}/resourceGroups/${local.tfstate_resource_group_name["dev"]}/providers/Microsoft.Storage/storageAccounts/${local.tfstate_storage_account_name["dev"]}"
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = module.uami["dev"].principal_id
}

resource "azurerm_role_assignment" "test_state_storage" {
  provider = azurerm.test

  scope                = "/subscriptions/${var.subscription_ids.test}/resourceGroups/${local.tfstate_resource_group_name["test"]}/providers/Microsoft.Storage/storageAccounts/${local.tfstate_storage_account_name["test"]}"
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = module.uami["test"].principal_id
}

resource "azurerm_role_assignment" "prod_state_storage" {
  provider = azurerm.prod

  scope                = "/subscriptions/${var.subscription_ids.prod}/resourceGroups/${local.tfstate_resource_group_name["prod"]}/providers/Microsoft.Storage/storageAccounts/${local.tfstate_storage_account_name["prod"]}"
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = module.uami["prod"].principal_id
}

# ---------------------------------------------------------------------------
# Cross-env capacity registry read: every non-tools UAMI needs to read
# stacks/shared's state for "tools", since the default shared-cross-env
# Fabric capacity is homed there - see stacks/tenant/locals.tf
# (data.terraform_remote_state.shared). The tools UAMI already has
# Contributor on its own state storage account from tools_state_storage above.
#
# Each role assignment is scoped to the dev/test/prod subscription (matching
# the principal's home subscription for provider routing) but targets the
# tools storage account resource - Azure RBAC allows assigning roles on
# resources in other subscriptions as long as the caller has
# Microsoft.Authorization/roleAssignments/write on that scope, which the
# human running this bootstrap stack has.
# ---------------------------------------------------------------------------
resource "azurerm_role_assignment" "tools_state_storage_reader_dev" {
  provider = azurerm.dev

  scope                = "/subscriptions/${var.subscription_ids.tools}/resourceGroups/${local.tfstate_resource_group_name["tools"]}/providers/Microsoft.Storage/storageAccounts/${local.tfstate_storage_account_name["tools"]}"
  role_definition_name = "Storage Blob Data Reader"
  principal_id         = module.uami["dev"].principal_id
}

resource "azurerm_role_assignment" "tools_state_storage_reader_test" {
  provider = azurerm.test

  scope                = "/subscriptions/${var.subscription_ids.tools}/resourceGroups/${local.tfstate_resource_group_name["tools"]}/providers/Microsoft.Storage/storageAccounts/${local.tfstate_storage_account_name["tools"]}"
  role_definition_name = "Storage Blob Data Reader"
  principal_id         = module.uami["test"].principal_id
}

resource "azurerm_role_assignment" "tools_state_storage_reader_prod" {
  provider = azurerm.prod

  scope                = "/subscriptions/${var.subscription_ids.tools}/resourceGroups/${local.tfstate_resource_group_name["tools"]}/providers/Microsoft.Storage/storageAccounts/${local.tfstate_storage_account_name["tools"]}"
  role_definition_name = "Storage Blob Data Reader"
  principal_id         = module.uami["prod"].principal_id
}

# ---------------------------------------------------------------------------
# Bastion/jumpbox access: every UAMI can open a Bastion tunnel to the tools
# jumpbox to reach private endpoints, including in dev/test/prod via the
# spoke-to-spoke peering that's already in place.
# ---------------------------------------------------------------------------
resource "azurerm_role_assignment" "bastion_reader" {
  for_each = toset(local.environments)

  scope                = var.bastion_resource_id
  role_definition_name = "Reader"
  principal_id         = module.uami[each.key].principal_id
}

resource "azurerm_role_assignment" "jumpbox_vm_user_login" {
  for_each = toset(local.environments)

  scope                = var.jumpbox_vm_resource_id
  role_definition_name = "Virtual Machine User Login"
  principal_id         = module.uami[each.key].principal_id
}

# ---------------------------------------------------------------------------
# Jumpbox RBAC delegation: each UAMI needs to be able to create role
# assignments scoped to the jumpbox VM so that stacks/tenant can grant
# Virtual Machine User Login to tenant Entra groups. Without this, the
# dev/test/prod UAMIs (which only have RBAC Admin on their own subscription)
# would be unable to create assignments on a resource in the tools subscription.
# ---------------------------------------------------------------------------
resource "azurerm_role_assignment" "jumpbox_rbac_admin" {
  for_each = toset(local.environments)

  scope                = var.jumpbox_vm_resource_id
  role_definition_name = "Role Based Access Control Administrator"
  principal_id         = module.uami[each.key].principal_id
}
