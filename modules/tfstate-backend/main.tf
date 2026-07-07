resource "azurerm_resource_group" "tfstate" {
  name     = var.resource_group_name
  location = var.location

  tags = merge(var.tags, { "managed-by" = "terraform" })
}

resource "azurerm_storage_account" "tfstate" {
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
  }

  network_rules {
    default_action = "Deny"
    bypass         = ["AzureServices"]
  }

  tags = merge(var.tags, { "managed-by" = "terraform" })
}

resource "azurerm_storage_container" "tfstate" {
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