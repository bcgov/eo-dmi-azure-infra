# This stack creates the storage account that every other stack uses as its
# remote backend, so it cannot depend on that backend for its own state.
#
# Single-phase bootstrap: the spoke VNet/subnet already exists (managed by the
# platform team), so the storage account can be created with
# public_network_access_enabled = false from the very first apply - no
# temporary-public window is needed.
#
# First run: apply with this local backend, from a workstation/runner that
# can reach this subscription (e.g. via the tools Bastion/jumpbox proxy for
# dev/test/prod, or directly for tools).
#
# After the first apply succeeds, optionally migrate this stack's own state
# into the storage account it just created:
#
#   terraform init -migrate-state \
#     -backend-config="resource_group_name=$(terraform output -raw resource_group_name)" \
#     -backend-config="storage_account_name=$(terraform output -raw storage_account_name)" \
#     -backend-config="container_name=tfstate" \
#     -backend-config="key=bootstrap/state-backend-<environment>.tfstate" \
#     -backend-config="use_azuread_auth=true"
#
# then uncomment the block below and re-run `terraform init`.
#
# terraform {
#   backend "azurerm" {
#     use_azuread_auth = true
#   }
# }
