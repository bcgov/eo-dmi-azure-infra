# Adds a private-endpoint subnet to an existing platform spoke VNet.
#
# Run this before stacks/bootstrap/state-backend when the VNet already
# exists but has no PE subnet (typical first-time setup for test/prod whose
# spokes are managed by the BC Gov platform team).
#
# If the spoke VNet itself does not exist yet (brand-new subscription not
# yet connected to the platform VWAN), use stacks/bootstrap/networking
# instead — it creates the VNet and this subnet in one shot.
#
# After apply, copy the subnet_id output into:
#   - params/global/network-reference.yaml   (pe_subnet_id for this env)
#   - params/bootstrap/<env>.tfvars          (subnet_id)
#   - params/<env>/shared.tfvars             (pe_subnet_id)

data "azurerm_virtual_network" "spoke" {
  name                = var.vnet_name
  resource_group_name = var.vnet_resource_group
}

resource "azurerm_subnet" "pe" {
  name                 = var.subnet_name
  resource_group_name  = var.vnet_resource_group
  virtual_network_name = data.azurerm_virtual_network.spoke.name
  address_prefixes     = [var.address_prefix]

  # Required for private endpoints — Azure blocks PE creation in subnets
  # where this policy is Enabled.
  private_endpoint_network_policies = "Disabled"
}
