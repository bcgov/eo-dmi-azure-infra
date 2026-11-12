output "platform_resource_group_name" {
  description = "Name of the Terraform-managed platform RG (rg-<tenant>-<env>-platform)."
  value       = module.platform_rg.name
}


output "key_vault_id" {
  description = "Resource ID of the tenant's Key Vault, or null when create_key_vault = false."
  value       = var.create_key_vault ? module.key_vault[0].id : null

  # Fails the plan rather than silently dropping role assignments: with no vault
  # there is nothing to assign kv_rbac_assignments on.
  precondition {
    condition     = var.create_key_vault || length(var.kv_rbac_assignments) == 0
    error_message = "kv_rbac_assignments is set but create_key_vault = false - there is no vault to assign roles on. Empty the list or set create_key_vault = true."
  }
}

output "key_vault_uri" {
  description = "URI of the tenant's Key Vault (reachable only via the private endpoint), or null when create_key_vault = false."
  value       = var.create_key_vault ? module.key_vault[0].vault_uri : null
}

output "fabric_capacity_id" {
  description = "Resource ID of the Fabric capacity this tenant's workspaces should be assigned to - either a newly created dedicated capacity, or the shared capacity resolved via remote state (see locals.tf)."
  value       = var.create_dedicated_capacity ? module.dedicated_fabric_capacity[0].id : local.shared_capacity_id
}
