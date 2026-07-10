environment     = "test"
ministry_code   = "citz" # e.g. "citz" - see docs/platform-guide.md "Naming conventions". Must match params/bootstrap/identity.tfvars.
program_code    = "dap"  # e.g. "pmt"
subscription_id = "8e303ae8-ce14-4e85-9dc3-9d767a42dec8"
location        = "canadacentral"

# Copied from params/global/network-reference.yaml (environments.test)
subnet_id            = "/subscriptions/8e303ae8-ce14-4e85-9dc3-9d767a42dec8/resourceGroups/b9cee3-test-networking/providers/Microsoft.Network/virtualNetworks/b9cee3-test-vwan-spoke/subnets/privateendpoints-subnet"
private_dns_zone_ids = []

tags = {
  ministry    = "citz"
  application = "eo-dmi-dap-platform"
}
