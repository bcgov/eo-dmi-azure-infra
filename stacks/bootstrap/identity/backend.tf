# Run stacks/bootstrap/state-backend for "tools" first (and migrate its state
# into the storage account it creates - see that stack's backend.tf).
#
# This stack's state then lives in that same storage account:
#
#   terraform init \
#     -backend-config="resource_group_name=rg-<ministry>-<program>-tfstate-tools" \
#     -backend-config="storage_account_name=st<ministry><program>toolstfstate" \
#     -backend-config="container_name=tfstate" \
#     -backend-config="key=bootstrap/identity.tfstate" \
#     -backend-config="use_azuread_auth=true"
#
# This stack is applied by a human with elevated rights (User Access
# Administrator or Owner) across all 4 subscriptions - it is what creates the
# UAMIs that CI uses afterwards, so CI cannot bootstrap it.

terraform {
  backend "azurerm" {
    use_azuread_auth = true
  }
}
