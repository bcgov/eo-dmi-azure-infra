environment     = "tools"
ministry_code   = "citz" # e.g. "citz" - see docs/platform-guide.md "Naming conventions"
program_code    = "dap"  # e.g. "pmt"
subscription_id = "ffc5e617-7f2d-4ddb-8b57-33fc43989a8c"
location        = "canadacentral"
azure_tenant_id = "6fdb5200-3d0d-4a8a-b036-d3685e359adc"

# Copied from params/global/network-reference.yaml (environments.tools)
pe_subnet_id         = "/subscriptions/ffc5e617-7f2d-4ddb-8b57-33fc43989a8c/resourceGroups/b9cee3-tools-networking/providers/Microsoft.Network/virtualNetworks/b9cee3-tools-vwan-spoke/subnets/privateendpoints-subnet"
private_dns_zone_ids = []

# Shared Bastion jumpbox (bcgov/eo-dmi-alz-bastion-jumpbox) - one VM for all envs/tenants.
# Tenant teams are granted Virtual Machine User Login on this VM by stacks/tenant.
jumpbox_vm_id = "/subscriptions/ffc5e617-7f2d-4ddb-8b57-33fc43989a8c/resourceGroups/eo-dmi-alz-bastion-jumpbox-tools/providers/Microsoft.Compute/virtualMachines/eo-dmi-alz-bastion-jumpbox-jumpbox"

tags = {
  ministry    = "citz"
  application = "eo-dmi-dap-platform"
}
