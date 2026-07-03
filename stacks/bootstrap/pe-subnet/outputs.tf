output "subnet_id" {
  description = "Resource ID of the created PE subnet. Copy this into params/global/network-reference.yaml (pe_subnet_id), params/bootstrap/<env>.tfvars (subnet_id), and params/<env>/shared.tfvars (pe_subnet_id)."
  value       = azurerm_subnet.pe.id
}

output "subnet_name" {
  description = "Name of the created PE subnet."
  value       = azurerm_subnet.pe.name
}

output "address_prefix" {
  description = "CIDR block assigned to the PE subnet."
  value       = azurerm_subnet.pe.address_prefixes[0]
}
