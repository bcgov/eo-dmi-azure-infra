# Backend config is supplied via -backend-config at init time, one state file
# per tenant per environment - so onboarding/changing one tenant never
# re-plans any other tenant:
#
#   terraform init \
#     -backend-config="resource_group_name=rg-<ministry>-<program>-tfstate-<env>" \
#     -backend-config="storage_account_name=st<ministry><program><env>tfstate" \
#     -backend-config="container_name=tfstate" \
#     -backend-config="key=tenant/<tenant-name>.tfstate" \
#     -backend-config="use_azuread_auth=true"

terraform {
  backend "azurerm" {
    use_azuread_auth = true
  }
}
