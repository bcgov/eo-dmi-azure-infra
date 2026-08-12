tenant_name         = "pmt"
environment         = "dev"
tenant_program_name = null

# Key Vault role assignments — add individuals or groups as needed.
# Key Vault Secrets Officer: create, update, delete secrets.
# Do NOT use Key Vault Administrator — that also controls vault networking, which is ops-only.
kv_rbac_assignments = []

create_dedicated_capacity = false
fabric_capacity_name      = null

# Do NOT set `tags` here - it would replace the platform-wide tags from
# shared.tfvars instead of merging. `tenant` and `environment` are added
# automatically; use `tenant_tags` for anything extra.
