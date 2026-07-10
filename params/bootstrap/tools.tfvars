environment     = "tools"
ministry_code   = "citz" # e.g. "citz" - see docs/platform-guide.md "Naming conventions". Must match params/bootstrap/identity.tfvars.
program_code    = "dap"  # e.g. "pmt"
subscription_id = "ffc5e617-7f2d-4ddb-8b57-33fc43989a8c"
location        = "canadacentral"

# Copied from params/global/network-reference.yaml (environments.tools)
subnet_id = "/subscriptions/ffc5e617-7f2d-4ddb-8b57-33fc43989a8c/resourceGroups/b9cee3-tools-networking/providers/Microsoft.Network/virtualNetworks/b9cee3-tools-vwan-spoke/subnets/privateendpoints-subnet"

tags = {
  ministry    = "citz"
  application = "eo-dmi-dap-platform"
}
