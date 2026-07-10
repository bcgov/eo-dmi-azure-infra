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

# BC Gov ALZ policy requires every subnet to have an NSG attached at creation
# time. azurerm_subnet + azurerm_subnet_network_security_group_association makes
# two separate API calls, so the subnet exists for a moment without an NSG and
# the policy denies it. azapi_resource lets us embed the NSG in a single PUT,
# satisfying the policy in one shot.
#
# For a PE-only subnet no custom rules are needed — the NSG is a compliance
# placeholder; private endpoint traffic is controlled by the PE approval model
# and storage account network rules instead.
resource "azurerm_network_security_group" "pe" {
  name                = "nsg-${var.subnet_name}"
  location            = data.azurerm_virtual_network.spoke.location
  resource_group_name = var.vnet_resource_group
}

resource "azapi_resource" "pe_subnet" {
  type      = "Microsoft.Network/virtualNetworks/subnets@2024-01-01"
  name      = var.subnet_name
  parent_id = data.azurerm_virtual_network.spoke.id

  body = {
    properties = {
      addressPrefix = var.address_prefix
      networkSecurityGroup = {
        id = azurerm_network_security_group.pe.id
      }
      # Required for private endpoints — Azure blocks PE creation in subnets
      # where this is Enabled.
      privateEndpointNetworkPolicies = "Disabled"
    }
  }
}
