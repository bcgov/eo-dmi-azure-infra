output "resource_group_name" {
  description = "Name of the resource group holding the state storage account."
  value       = azurerm_resource_group.tfstate.name
}

output "storage_account_name" {
  description = "Name of the Terraform state storage account."
  value       = azurerm_storage_account.tfstate.name
}

output "storage_account_id" {
  description = "Resource ID of the Terraform state storage account."
  value       = azurerm_storage_account.tfstate.id
}

output "container_name" {
  description = "Name of the blob container holding tfstate files."
  value       = azurerm_storage_container.tfstate.name
}
