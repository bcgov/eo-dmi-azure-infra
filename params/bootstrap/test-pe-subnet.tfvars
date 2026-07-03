# stacks/bootstrap/pe-subnet — test subscription
# Adds privateendpoints-subnet to the existing b9cee3-test-vwan-spoke VNet.
# VNet address space: 10.46.8.0/24 — subnet takes the first /27.

subscription_id     = "8e303ae8-ce14-4e85-9dc3-9d767a42dec8"
vnet_resource_group = "b9cee3-test-networking"
vnet_name           = "b9cee3-test-vwan-spoke"
subnet_name         = "privateendpoints-subnet"
address_prefix      = "10.46.8.0/27"
