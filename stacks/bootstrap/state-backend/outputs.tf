output "resource_group_name" {
  description = "Name of the resource group holding the state storage account."
  value       = module.tfstate_backend.resource_group_name
}

output "storage_account_name" {
  description = "Name of the Terraform state storage account."
  value       = module.tfstate_backend.storage_account_name
}

output "storage_account_id" {
  description = "Resource ID of the Terraform state storage account."
  value       = module.tfstate_backend.storage_account_id
}

output "container_name" {
  description = "Name of the blob container holding tfstate files."
  value       = module.tfstate_backend.container_name
}
