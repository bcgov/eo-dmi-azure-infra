environment     = "prod"
ministry_code   = "citz" # e.g. "citz" - see docs/platform-guide.md "Naming conventions". Must match params/bootstrap/identity.tfvars.
program_code    = "dap"  # e.g. "pmt"
subscription_id = "77336ca9-272d-4cad-9d76-02f51399d697"
location        = "canadacentral"

# Copied from params/global/network-reference.yaml (environments.prod)
subnet_id            = "/subscriptions/77336ca9-272d-4cad-9d76-02f51399d697/resourceGroups/b9cee3-prod-networking/providers/Microsoft.Network/virtualNetworks/b9cee3-prod-vwan-spoke/subnets/privateendpoints-subnet"
private_dns_zone_ids = []

tags = {
  ministry    = "citz"
  application = "eo-dmi-dap-platform"
}
