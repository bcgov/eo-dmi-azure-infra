# Ministry of Forests' CORP-Forest Intelligence Hub Resources
tenant_name          = "corp-fih"
tenant_ministry_code = "for"
environment          = "dev"
tenant_program_name  = null

# Key Vault role assignments — add individuals or groups as needed.
# Key Vault Secrets Officer: create, update, delete secrets.
# Do NOT use Key Vault Administrator — that also controls vault networking, which is ops-only.
kv_rbac_assignments = [
    {
        role_definition_name = "Key Vaults Secrets Officer"
        principal_id         = "38015b5c-19d9-411f-aa25-64720162a95a" #Thomas
    },
    {
        role_definition_name = "Key Vaults Secrets Officer"
        principal_id         = "4f230786-445d-45d3-8782-cdb4ff8c62fd" #Jaskirat
    }
]

# No dediacted fabric capacity created for FOR-FIH
create_dedicated_capacity = false
fabric_capacity_name      = null

# Do NOT set `tags` here - it would replace the platform-wide tags from
