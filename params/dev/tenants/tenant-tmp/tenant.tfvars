# Test tenant - used to validate the tenant stack before onboarding real tenants.
# To onboard a real tenant, copy this directory to params/dev/tenants/<tenant>/,
# then copy again under params/test/tenants/<tenant>/ and params/prod/tenants/<tenant>/
# to promote through environments.

tenant_name         = "tenant-tmp"
environment         = "dev"
tenant_program_name = null

# Entra ID object IDs granted Virtual Machine User Login on the shared Bastion jumpbox.
# These principals can open a Bastion tunnel to reach the tenant's private endpoints.
# Can be individual user object IDs or Entra group object IDs.
jumpbox_principal_ids = ["acc400f6-00af-4401-8720-9fa3770b1845"]

# Key Vault role assignments for this tenant's KV.
# Key Vault Secrets Officer: allows the tenant team to create, update, and
# delete secrets — appropriate for teams managing their own secrets.
# Do NOT use Key Vault Administrator here — that role also controls vault
# networking and access policy configuration, which is ops-only territory.
kv_rbac_assignments = [
  {
    role_definition_name = "Key Vault Secrets Officer"
    principal_id         = "acc400f6-00af-4401-8720-9fa3770b1845"
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

