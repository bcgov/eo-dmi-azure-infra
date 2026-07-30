environment     = "dev"
ministry_code   = "citz"
program_code    = "dap"
subscription_id = "5206cf0e-3bf0-4224-8b2c-1acd3cfa08f3"
location        = "canadacentral"
azure_tenant_id = "6fdb5200-3d0d-4a8a-b036-d3685e359adc"

# Copied from params/global/network-reference.yaml (environments.dev)
pe_subnet_id         = "/subscriptions/5206cf0e-3bf0-4224-8b2c-1acd3cfa08f3/resourceGroups/b9cee3-dev-networking/providers/Microsoft.Network/virtualNetworks/b9cee3-dev-vwan-spoke/subnets/arch-dev-dap-etl-subnet"
private_dns_zone_ids = []

tags = {
  ministry    = "citz"
  application = "eo-dmi-dap-platform"
}


