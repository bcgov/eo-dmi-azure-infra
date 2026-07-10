resource "azurerm_resource_group" "tfstate" {
  name     = var.resource_group_name
  location = var.location

  tags = merge(var.tags, { "managed-by" = "terraform" })
}

resource "azurerm_storage_account" "tfstate" {
  #checkov:skip=CKV_AZURE_33:Queue service is not used by this storage account (Terraform state is blob-only); queue logging is not applicable
  #checkov:skip=CKV2_AZURE_1:Customer-managed key encryption for Terraform state would create a circular dependency — the key vault holding the key is itself managed by this state
  name                = var.storage_account_name
  resource_group_name = azurerm_resource_group.tfstate.name
  location            = var.location

  account_tier             = "Standard"
  account_replication_type = var.account_replication_type
  min_tls_version          = "TLS1_2"

  public_network_access_enabled    = false
  shared_access_key_enabled        = false
  cross_tenant_replication_enabled = false
  allow_nested_items_to_be_public  = false

  blob_properties {
    versioning_enabled = true

    # CKV2_AZURE_38: retain deleted blobs for 7 days to allow recovery
    delete_retention_policy {
      days = 7
    }
  }

  network_rules {
    default_action = "Deny"
    bypass         = ["AzureServices"]
  }

  tags = merge(var.tags, { "managed-by" = "terraform" })
}

resource "azurerm_storage_container" "tfstate" {
  #checkov:skip=CKV2_AZURE_21:Blob request logging requires azurerm_storage_management_policy; not configurable via azurerm_storage_account blob_properties in provider v4
  name                  = "tfstate"
  storage_account_id    = azurerm_storage_account.tfstate.id
  container_access_type = "private"
}

module "blob_private_endpoint" {
  source = "../private-endpoint"

  name                 = "pe-${var.storage_account_name}-blob"
  resource_group_name  = azurerm_resource_group.tfstate.name
  location             = var.location
  subnet_id            = var.subnet_id
  target_resource_id   = azurerm_storage_account.tfstate.id
  subresource_names    = ["blob"]
  private_dns_zone_ids = var.private_dns_zone_ids
  tags                 = var.tags
}