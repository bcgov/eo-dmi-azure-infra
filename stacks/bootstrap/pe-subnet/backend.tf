# This is a one-shot bootstrap stack run before the state storage account
# exists, so it starts on local state.
#
# After apply, optionally migrate state into the storage account created by
# stacks/bootstrap/state-backend for this environment:
#
#   terraform init -migrate-state \
#     -backend-config="resource_group_name=rg-<ministry>-<program>-tfstate-<env>" \
#     -backend-config="storage_account_name=st<ministry><program><env>tfstate" \
#     -backend-config="container_name=tfstate" \
#     -backend-config="key=bootstrap/pe-subnet-<env>.tfstate" \
#     -backend-config="use_azuread_auth=true"
#
# then uncomment the block below and re-run `terraform init`.
#
# terraform {
#   backend "azurerm" {
#     use_azuread_auth = true
#   }
# }
