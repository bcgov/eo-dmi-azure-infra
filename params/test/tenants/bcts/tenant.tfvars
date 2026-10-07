tenant_name         = "bcts"
environment         = "test"
tenant_program_name = null

# Key Vault role assignments for this tenant's KV.
# Key Vault Secrets Officer: allows the tenant team to create, update, and
# delete secrets — appropriate for teams managing their own secrets.
# Do NOT use Key Vault Administrator here — that role also controls vault
# networking and access policy configuration, which is ops-only territory.
#
# Data-plane access alone is not enough: the vault is private-endpoint only, so
# each principal here also needs a Bastion tunnel, granted centrally via
# jumpbox_principal_ids in params/global/platform-access.tfvars.
#
# TODO: replace with the bcts team Entra group object ID once that group exists.
kv_rbac_assignments = [
  {
    role_definition_name = "Key Vault Secrets Officer"
    principal_id         = "8a0af36a-54cd-4432-8a5e-3a2b55209eae" # sree
  }
]

# Shares fccitzbctsnonprod (F4, homed in tools) with the dev environment.
# See params/global/fabric-capacities.yaml. Resolved to a resource ID via
# stacks/shared's remote state - exposed as the fabric_capacity_id output for
# later workspace-assignment automation. Assigning workspaces to the capacity is
# currently manual, in the Fabric portal.
create_dedicated_capacity = false
fabric_capacity_name      = "bcts-nonprod"

# Do NOT set `tags` here - it would replace the platform-wide tags from
# shared.tfvars instead of merging. `tenant` and `environment` are added
# automatically; use `tenant_tags` for anything extra.
