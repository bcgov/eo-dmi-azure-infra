# BC Wildfire Service (WF), Ministry of Forests (FOR).
tenant_name          = "wf"
tenant_ministry_code = "for" # owning ministry - names become rg-for-wf-prod etc. Set once: changing it recreates every resource.
environment          = "prod"
tenant_program_name  = null

# RG + Fabric capacity only for now - no Key Vault or private endpoint.
# Turning this on later is safe (creates the vault). Turning it off once a vault
# exists destroys it. kv_rbac_assignments must stay empty while false.
create_key_vault    = false
kv_rbac_assignments = []

# Dedicated F4 in this tenant's platform RG (rg-for-wf-prod). Generated name:
# fcforwfprod (fc<ministry><tenant><env>), so no dedicated_capacity_name.
#
# fabric_capacity_admins MUST be UPNs, not object IDs - Microsoft.Fabric rejects
# a raw object ID with "400 BadRequest: All provided principals must be
# existing, user or service principals". The list is a full replacement on each
# apply, and Terraform reverts admins added by hand in the Fabric portal.
create_dedicated_capacity = true
dedicated_capacity_sku    = "F4"
fabric_capacity_admins = [
  "Abigail.Michel@gov.bc.ca",      # abi
  "Dana.Diotte@gov.bc.ca",         # dana
  "Krishna.Rajendharan@gov.bc.ca", # krishna
]
fabric_capacity_name = null

# Do NOT set `tags` here - it would replace the platform-wide tags from
# shared.tfvars instead of merging. `ministry` (from tenant_ministry_code),
# `tenant` and `environment` are added automatically; use `tenant_tags` for
# anything extra.
