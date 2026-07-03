output "id" {
  description = "Resource ID of the tenant platform resource group."
  value       = azurerm_resource_group.platform.id
}

output "name" {
  description = "Name of the tenant platform resource group."
  value       = azurerm_resource_group.platform.name
}

output "location" {
  description = "Location of the tenant platform resource group."
  value       = azurerm_resource_group.platform.location
}
