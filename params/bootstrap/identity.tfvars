location = "canadacentral"

ministry_code = "citz"   # e.g. "citz" - see docs/platform-guide.md "Naming conventions". Must match every params/bootstrap/<env>.tfvars.
program_code  = "dap"    # e.g. "dap"

subscription_ids = {
  tools = "ffc5e617-7f2d-4ddb-8b57-33fc43989a8c"
  dev   = "5206cf0e-3bf0-4224-8b2c-1acd3cfa08f3"
  test  = "8e303ae8-ce14-4e85-9dc3-9d767a42dec8"
  prod  = "77336ca9-272d-4cad-9d76-02f51399d697"
}

github_org  = "bcgov"
github_repo = "eo-dmi-azure-infra"

# From bcgov/eo-dmi-alz-bastion-jumpbox in b9cee3-tools
bastion_resource_id    = "/subscriptions/ffc5e617-7f2d-4ddb-8b57-33fc43989a8c/resourceGroups/eo-dmi-alz-bastion-jumpbox-tools/providers/Microsoft.Network/bastionHosts/eo-dmi-alz-bastion-jumpbox-bastion"
jumpbox_vm_resource_id = "/subscriptions/ffc5e617-7f2d-4ddb-8b57-33fc43989a8c/resourceGroups/EO-DMI-ALZ-BASTION-JUMPBOX-TOOLS/providers/Microsoft.Compute/virtualMachines/eo-dmi-alz-bastion-jumpbox-jumpbox"

tags = {
  ministry    = "citz"
  application = "eo-dmi-dap-platform"
}
