# BC Wildfire Service (WF), Ministry of Forests (FOR).
tenant_name          = "wf"
tenant_ministry_code = "for" # owning ministry - names become rg-for-wf-dev etc. Set once: changing it recreates every resource.
environment          = "dev"
tenant_program_name  = null

# RG + Fabric capacity only for now - no Key Vault or private endpoint.
# Turning this on later is safe (creates the vault). Turning it off once a vault
# exists destroys it. kv_rbac_assignments must stay empty while false.
create_key_vault    = false
kv_rbac_assignments = []

# F4 in this tenant's own platform RG (rg-for-wf-dev) in the dev subscription.
# WF has a single non-prod environment, so this one capacity serves all of its
# non-prod work - hence the name override: the generated name would be
# fcforwfdev. Capacity name is ForceNew - never edit dedicated_capacity_name.
#
# fabric_capacity_admins MUST be UPNs, not object IDs - Microsoft.Fabric rejects
# a raw object ID with "400 BadRequest: All provided principals must be
# existing, user or service principals". The list is a full replacement on each
# apply, and Terraform reverts admins added by hand in the Fabric portal.
create_dedicated_capacity = true
dedicated_capacity_sku    = "F4"
dedicated_capacity_name   = "fcforwfnonprod"
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
