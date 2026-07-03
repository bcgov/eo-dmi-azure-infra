# stacks/bootstrap/pe-subnet — prod subscription
# Adds privateendpoints-subnet to the existing b9cee3-prod-vwan-spoke VNet.
# VNet address space: 10.46.152.0/24 — subnet takes the first /27.

subscription_id     = "77336ca9-272d-4cad-9d76-02f51399d697"
vnet_resource_group = "b9cee3-prod-networking"
vnet_name           = "b9cee3-prod-vwan-spoke"
subnet_name         = "privateendpoints-subnet"
address_prefix      = "10.46.152.0/27"
