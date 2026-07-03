output "id" {
  description = "Resource ID of the user-assigned managed identity."
  value       = azurerm_user_assigned_identity.this.id
}

output "principal_id" {
  description = "Object (principal) ID of the identity - used as the target for azurerm_role_assignment resources."
  value       = azurerm_user_assigned_identity.this.principal_id
}

output "client_id" {
  description = "Client (application) ID of the identity - used as AZURE_CLIENT_ID in GitHub Actions."
  value       = azurerm_user_assigned_identity.this.client_id
}

output "name" {
  description = "Name of the user-assigned managed identity."
  value       = azurerm_user_assigned_identity.this.name
}
