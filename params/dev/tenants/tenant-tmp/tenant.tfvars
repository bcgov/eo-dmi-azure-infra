# Test tenant - used to validate the tenant stack before onboarding real tenants.
# To onboard a real tenant, copy this directory to params/dev/tenants/<tenant>/,
# then copy again under params/test/tenants/<tenant>/ and params/prod/tenants/<tenant>/
# to promote through environments.

tenant_name         = "tenant-tmp"
environment         = "dev"
tenant_program_name = null

# Entra ID object ID of the group for the tenant-tmp team.
# This group is granted:
#   - Contributor on the workspace RG (rg-citz-tenant-tmp-dev-ws) — allows the
#     team to self-manage Azure resources in that RG (create/update/delete).
#     Does NOT allow assigning roles to others.
#   - Virtual Machine User Login on the shared Bastion jumpbox — allows the
#     team to open a tunnel to reach private endpoints (KV, storage, Fabric).
#   - Any roles listed in kv_rbac_assignments below.
#
# To add/remove people from all of the above: manage membership of this group
# in Entra ID (Azure Portal → Entra ID → Groups → find group → Members).
# No Terraform changes needed for membership changes.
# TODO: replace with the tenant-tmp dev team's Entra group object ID once group is set up
workspace_owners_group_object_id = "acc400f6-00af-4401-8720-9fa3770b1845"

# Key Vault role assignments for this tenant's KV.
# Key Vault Secrets Officer: allows the tenant team to create, update, and
# delete secrets — appropriate for teams managing their own secrets.
# Do NOT use Key Vault Administrator here — that role also controls vault
# networking and access policy configuration, which is ops-only territory.
kv_rbac_assignments = [
  {
    role_definition_name = "Key Vault Secrets Officer"
    principal_id         = "acc400f6-00af-4401-8720-9fa3770b1845" # TODO: replace with team Entra group object ID
  }
]

create_dedicated_capacity = false
# null: no Fabric capacity for this test tenant (avoids dependency on
# stacks/shared being applied in the tools environment during CI smoke tests).
fabric_capacity_name = null

tags = {
  tenant = "tenant-tmp"
}

# ci test
