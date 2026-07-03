output "identity_resource_group_name" {
  description = "Name of the resource group holding all 4 UAMIs."
  value       = azurerm_resource_group.identity.name
}

output "uami_client_ids" {
  description = "Client (application) IDs of the 4 UAMIs, keyed by environment. Set as AZURE_CLIENT_ID in the matching GitHub Environment."
  value = {
    for env, mod in module.uami : env => mod.client_id
  }
}

output "uami_principal_ids" {
  description = "Principal (object) IDs of the 4 UAMIs, keyed by environment."
  value = {
    for env, mod in module.uami : env => mod.principal_id
  }
}
