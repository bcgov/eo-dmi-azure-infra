environment     = "dev"
ministry_code   = "citz"   # e.g. "citz" - see docs/platform-guide.md "Naming conventions". Must match params/bootstrap/identity.tfvars.
program_code    = "dap"    # e.g. "dap"
subscription_id = "5206cf0e-3bf0-4224-8b2c-1acd3cfa08f3"
location        = "canadacentral"

# Copied from params/global/network-reference.yaml (environments.dev)
subnet_id = "/subscriptions/5206cf0e-3bf0-4224-8b2c-1acd3cfa08f3/resourceGroups/b9cee3-dev-networking/providers/Microsoft.Network/virtualNetworks/b9cee3-dev-vwan-spoke/subnets/arch-dev-dap-etl-subnet"
private_dns_zone_ids = []

tags = {
  ministry    = "citz"
  application = "eo-dmi-dap-platform"
}
