environment     = "test"
ministry_code   = "citz" # e.g. "citz" - see docs/platform-guide.md "Naming conventions"
program_code    = "dap"  # e.g. "dap"
subscription_id = "8e303ae8-ce14-4e85-9dc3-9d767a42dec8"
location        = "canadacentral"
azure_tenant_id = "6fdb5200-3d0d-4a8a-b036-d3685e359adc"

# Copied from params/global/network-reference.yaml (environments.test)
pe_subnet_id         = "/subscriptions/8e303ae8-ce14-4e85-9dc3-9d767a42dec8/resourceGroups/b9cee3-test-networking/providers/Microsoft.Network/virtualNetworks/b9cee3-test-vwan-spoke/subnets/privateendpoints-subnet"
private_dns_zone_ids = []

# Shared Bastion jumpbox (bcgov/eo-dmi-alz-bastion-jumpbox) - one VM for all envs/tenants.
# Tenant teams are granted Virtual Machine User Login on this VM by stacks/tenant.
jumpbox_vm_id = "/subscriptions/ffc5e617-7f2d-4ddb-8b57-33fc43989a8c/resourceGroups/eo-dmi-alz-bastion-jumpbox-tools/providers/Microsoft.Compute/virtualMachines/eo-dmi-alz-bastion-jumpbox-jumpbox"

tags = {
  ministry    = "citz"
  application = "eo-dmi-dap-platform"
}
