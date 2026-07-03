output "platform_resource_group_name" {
  description = "Name of the Terraform-managed platform RG (rg-<tenant>-<env>-platform)."
  value       = module.platform_rg.name
}

output "workspace_resource_group_name" {
  description = "Name of the self-service workspace RG (rg-<tenant>-<env>-workspace)."
  value       = module.workspace_rg.name
}

output "key_vault_id" {
  description = "Resource ID of the tenant's Key Vault."
  value       = module.key_vault.id
}

output "key_vault_uri" {
  description = "URI of the tenant's Key Vault (reachable only via the private endpoint)."
  value       = module.key_vault.vault_uri
}

output "fabric_capacity_id" {
  description = "Resource ID of the Fabric capacity this tenant's workspaces should be assigned to - either a newly created dedicated capacity, or the shared capacity resolved via remote state (see locals.tf)."
  value       = var.create_dedicated_capacity ? module.dedicated_fabric_capacity[0].id : local.shared_capacity_id
}
