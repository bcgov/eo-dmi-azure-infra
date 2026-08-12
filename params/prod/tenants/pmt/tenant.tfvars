tenant_name         = "pmt"
environment         = "prod"
tenant_program_name = null

# Key Vault role assignments — add individuals or groups as needed.
# Key Vault Secrets Officer: create, update, delete secrets.
# Do NOT use Key Vault Administrator — that also controls vault networking, which is ops-only.
kv_rbac_assignments = [
  {
    role_definition_name = "Key Vault Secrets Officer"
    principal_id         = "c2c84491-e623-4f89-b6be-7e36bff00374" # jakia
  },
  {
    role_definition_name = "Key Vault Secrets Officer"
    principal_id         = "8ec30563-1186-4a45-94d4-a7f8403924e7" # wei
  },
  {
    role_definition_name = "Key Vault Secrets Officer"
    principal_id         = "acc400f6-00af-4401-8720-9fa3770b1845" # krishna
  },
]

create_dedicated_capacity = false
fabric_capacity_name      = null

# Do NOT set `tags` here - it would replace the platform-wide tags from
# shared.tfvars instead of merging. `tenant` and `environment` are added
# automatically; use `tenant_tags` for anything extra.
