tenant_name         = "bcts"
environment         = "prod"
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

# Prod gets its own capacity rather than sharing: fccitzbctsprod, in this
# tenant's platform RG. Unlike the shared non-prod capacity, a dedicated one
# attributes cleanly in cost reports - one capacity, one tenant, one environment.
#
# fabric_capacity_admins MUST be UPNs, not object IDs. Microsoft.Fabric rejects
# a raw user object ID with "400 BadRequest: All provided principals must be
# existing, user or service principals" - see modules/fabric-capacity/variables.tf.
# The list is a full replacement on each apply, and Terraform reverts admins
# added by hand in the Fabric portal.
create_dedicated_capacity = true
dedicated_capacity_sku    = "F4"
fabric_capacity_admins = [
  "Krishna.Rajendharan@gov.bc.ca", # krishna
  "KRAJENDH@C.GOV.BC.CA",          # krajendh.c (elevated account)
]
fabric_capacity_name = null

# Do NOT set `tags` here - it would replace the platform-wide tags from
# shared.tfvars instead of merging. `tenant` and `environment` are added
# automatically; use `tenant_tags` for anything extra.
