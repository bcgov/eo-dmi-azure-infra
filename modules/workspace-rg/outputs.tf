output "id" {
  description = "Resource ID of the tenant workspace (self-service) resource group."
  value       = azurerm_resource_group.workspace.id
}

output "name" {
  description = "Name of the tenant workspace (self-service) resource group."
  value       = azurerm_resource_group.workspace.name
}
