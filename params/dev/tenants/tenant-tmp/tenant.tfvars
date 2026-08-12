# Test tenant - used to validate the tenant stack before onboarding real tenants.
# To onboard a real tenant, copy this directory to params/dev/tenants/<tenant>/,
# then copy again under params/test/tenants/<tenant>/ and params/prod/tenants/<tenant>/
# to promote through environments.

tenant_name         = "tenant-tmp"
environment         = "dev"
tenant_program_name = null

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

# Do NOT set `tags` here - it would replace the platform-wide tags from
# shared.tfvars instead of merging. `tenant` and `environment` are added
# automatically; use `tenant_tags` for anything extra.

# ci test

