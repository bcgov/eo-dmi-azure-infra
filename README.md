# eo-dmi-azure-infra

Terraform + GitHub Actions infrastructure for a multi-tenant EO-DMI Data Analytics Platform (DAP) on BC Gov's Azure Landing Zone

This repo manages the resources layered on top of the existing hub-spoke network: per-tenant resource groups, Key Vaults, private endpoints, Fabric capacities, Terraform state backends, and CI identities. The hub-spoke network, VNets, subnets, peering, and the Bastion/jumpbox are managed externally. See [`bcgov/eo-dmi-alz-bastion-jumpbox`](https://github.com/bcgov/eo-dmi-alz-bastion-jumpbox) for the Bastion/Jumpbox setup.

**The most common operation** is onboarding a tenant — jump to [Onboarding a tenant](#onboarding-a-tenant).

---

## Subscriptions

| Subscription | Role |
|---|---|
| `b9cee3-tools` | Platform identities (UAMIs), Bastion/jumpbox, shared Fabric capacity, tools state storage |
| `b9cee3-dev` | Tenant resources (dev), state storage |
| `b9cee3-test` | Tenant resources (test), state storage |
| `b9cee3-prod` | Tenant resources (prod), state storage |

---

## Repository layout

```
eo-dmi-azure-infra/
├── modules/              # Reusable Terraform building blocks (called by stacks, not deployed directly)
│   ├── tenant-platform-rg/
│   ├── workspace-rg/
│   ├── key-vault/
│   ├── private-endpoint/
│   ├── fabric-capacity/
│   ├── uami-federated/
│   └── tfstate-backend/
├── stacks/               # Deployable Terraform root modules — each has its own state file
│   ├── bootstrap/
│   │   ├── pe-subnet/      # Once per subscription — adds PE subnet to existing spoke VNet
│   │   ├── state-backend/  # Once per subscription — creates state storage account
│   │   └── identity/       # Once in tools — creates all 4 UAMIs and all RBAC
│   ├── shared/             # Per-env shared Fabric capacities
│   └── tenant/             # Per-tenant, per-env: KV + PE + workspace RG + optional capacity
├── params/               # Variable values — editing a file here is what triggers a CI deploy
│   ├── global/
│   │   ├── fabric-capacities.yaml   # Registry of shared Fabric capacities
│   │   └── network-reference.yaml   # Existing VNet/subnet resource IDs (fill in once)
│   ├── bootstrap/                   # Inputs for the one-time bootstrap stacks
│   └── <tools|dev|test|prod>/
│       ├── shared.tfvars            # Per-env shared values (subscription, subnets, etc.)
│       └── tenants/<tenant>/
│           └── tenant.tfvars        # Per-tenant onboarding record
├── scripts/
│   ├── bastion-proxy.sh    # Opens/closes SOCKS5 tunnel via the tools Bastion jumpbox
│   └── detect-changes.sh   # Used by CI to determine what changed in a given diff
└── .github/workflows/
    ├── pr-validate.yml     # Runs lint + plan on every PR
    └── deploy.yml          # Runs apply on merge to main
```

---

## Onboarding a tenant

No changes to modules or stacks needed — only add files under `params/`.

### 1. Copy the example tenant directory

```bash
cp -r params/dev/tenants/tenant-tmp params/dev/tenants/<tenant>
```

### 2. Edit `params/dev/tenants/<tenant>/tenant.tfvars`

```hcl
tenant_name = "<tenant>"   # lowercase, hyphens only — appears in all Azure resource names
environment = "dev"

# Optional sub-program segment — adds it to every resource name:
#   rg-citz-<tenant>-<tenant_program_name>-dev  instead of  rg-citz-<tenant>-dev
# tenant_program_name = "pdt"

# Object ID of the Entra ID group for this tenant's team.
# The group gets:
#   - Contributor on the workspace RG (rg-citz-<tenant>-dev-ws)
#     → the team can create/update/delete any resource inside that RG
#     → does NOT allow assigning roles to others
#   - Virtual Machine User Login on the shared Bastion jumpbox
#     → allows the team to open a Bastion tunnel to reach their Key Vault and private endpoints
# The group must already exist — this repo does not create Entra ID groups.
# To add/remove people: manage the group membership in Entra ID (no Terraform changes needed).
workspace_owners_group_object_id = "<entra-group-object-id>"

# Key Vault role assignments for this tenant's KV.
# Key Vault Secrets Officer: create, update, delete secrets — correct for tenant teams.
# Do NOT use Key Vault Administrator — that also controls vault networking and access policy,
# which is ops-only territory.
kv_rbac_assignments = [
  {
    role_definition_name = "Key Vault Secrets Officer"
    principal_id          = "<entra-group-object-id>"   # same group as above, or a different principal
  }
]

# Fabric capacity — use the default shared cross-env capacity:
create_dedicated_capacity = false
fabric_capacity_name      = "shared-cross-env"   # logical key from params/global/fabric-capacities.yaml

tags = {
  tenant = "<tenant>"
}
```

### 3. Open a PR

```bash
git checkout -b onboard/<tenant>
git add params/dev/tenants/<tenant>/
git commit -m "onboard <tenant> to dev"
git push origin onboard/<tenant>
# open PR on GitHub
```

`pr-validate.yml` detects the new directory and runs `terraform plan`. Review the plan in the PR checks — it should show 4 resources: platform RG, Key Vault, KV private endpoint, workspace RG.

### 4. Merge

`deploy.yml` applies the plan. The tenant team can access their workspace RG and Key Vault immediately.

> **Note on Bastion access**: the `Virtual Machine User Login` assignment on the shared jumpbox is currently **commented out** in `stacks/tenant/main.tf`. It requires the dev/test/prod UAMIs to have `Role Based Access Control Administrator` scoped to the jumpbox VM first. This is already coded in `stacks/bootstrap/identity` as `jumpbox_rbac_admin` but needs to be applied. Re-apply `stacks/bootstrap/identity`, then uncomment the `jumpbox_vm_login` block in `stacks/tenant/main.tf`.

---

## Promoting a tenant to test/prod

Promotion is just copying `tenant.tfvars` to the next environment. Each environment has its own state file, so onboarding or changing one tenant never re-plans another.

```bash
# Dev → test
cp -r params/dev/tenants/<tenant> params/test/tenants/<tenant>
sed -i '' 's/environment = "dev"/environment = "test"/' \
    params/test/tenants/<tenant>/tenant.tfvars

# Test → prod
cp -r params/test/tenants/<tenant> params/prod/tenants/<tenant>
sed -i '' 's/environment = "test"/environment = "prod"/' \
    params/prod/tenants/<tenant>/tenant.tfvars
```

Open a PR with the new files. The `test` and `prod` GitHub Environments have required reviewers — the apply job pauses for approval before running.

You can promote dev→test and test→prod in the same PR, or in separate PRs. Separate PRs give you a natural gate.

---

## Fabric capacity

### Give a tenant a dedicated capacity

Edit the tenant's `tenant.tfvars` for the relevant environment:

```hcl
create_dedicated_capacity = true
dedicated_capacity_sku    = "F4"               # choose SKU
fabric_capacity_admins    = ["admin@gov.bc.ca"]
# fabric_capacity_name can be removed or left as null when using dedicated
```

PR the change. The plan will show `fc-citz-<tenant>-[tenant_program-]<env>` being added.

### Add a new shared capacity

Edit `params/global/fabric-capacities.yaml`:

```yaml
capacities:
  shared-cross-env:   # existing
    ...

  shared-dev:         # new — homed in dev, usable by all dev tenants
    scope: shared-env
    home_env: dev
    sku: F8
    administrator_members:
      - "fabric-platform-admins@gov.bc.ca"
```

The logical key (`shared-dev`) becomes the Azure resource name as `fc-citz-dap-shared-dev`. To have a tenant use the new capacity, update their `tenant.tfvars` with `fabric_capacity_name = "shared-dev"` — that PR must be merged after the capacity exists.

---

## One-time bootstrap

Run locally as a platform team member with Owner rights across all 4 subscriptions. Requires Azure CLI, Terraform, and connectivity to the Bastion jumpbox for dev/test/prod state storage.

### Before you start

Replace all `<TODO-...>` placeholders with real values:

1. **`params/global/network-reference.yaml`** — spoke VNet name and `snet-pe` subnet resource ID for each environment.
2. **`params/global/fabric-capacities.yaml`** — real admin UPN/object ID for `shared-cross-env`.
3. **`params/<env>/shared.tfvars`** (all 4 envs) — `subscription_id`, `azure_tenant_id`, `pe_subnet_id`.
4. **`params/bootstrap/*.tfvars`** — subscription IDs, Bastion and jumpbox resource IDs, `ministry_code`, `program_code`, `github_repo`.

`ministry_code` and `program_code` must be identical across every `*.tfvars` — they are used to compute state storage account names, and a mismatch will cause RBAC grants to target the wrong accounts.

### Step 1 — Create PE subnet (test and prod only)

Run this before `state-backend` for subscriptions whose spoke VNet has no PE subnet yet:

```bash
cd stacks/bootstrap/pe-subnet
terraform init
terraform apply -var-file=../../../params/bootstrap/test-pe-subnet.tfvars
terraform apply -var-file=../../../params/bootstrap/prod-pe-subnet.tfvars
```

Copy the `subnet_id` output into `params/global/network-reference.yaml`, `params/bootstrap/<env>.tfvars`, and `params/<env>/shared.tfvars` for each subscription.

### Step 2 — Create state storage (once per subscription)

```bash
cd stacks/bootstrap/state-backend
terraform init   # starts on local state

terraform apply -var-file=../../../params/bootstrap/tools.tfvars
terraform apply -var-file=../../../params/bootstrap/dev.tfvars
terraform apply -var-file=../../../params/bootstrap/test.tfvars
terraform apply -var-file=../../../params/bootstrap/prod.tfvars
```

### Step 3 — Create UAMIs and RBAC (once, into tools)

```bash
cd stacks/bootstrap/identity
terraform init \
  -backend-config=resource_group_name=rg-<ministry>-<program>-tfstate-tools \
  -backend-config=storage_account_name=st<ministry><program>toolstfstate \
  -backend-config=container_name=tfstate \
  -backend-config=key=bootstrap/identity.tfstate \
  -backend-config=use_azuread_auth=true

terraform apply -var-file=../../../params/bootstrap/identity.tfvars
```

After apply, run `terraform output uami_client_ids` — you'll need these 4 client IDs for the GitHub configuration step.

After this, CI is self-sufficient: no service principals, no stored secrets.

---

## GitHub configuration (after bootstrap)

**Repo-level Variables** (Settings → Secrets and variables → Actions → Variables tab):

| Variable | Value |
|---|---|
| `MINISTRY_CODE` | Same `ministry_code` used in every `*.tfvars` (e.g. `citz`) |
| `PROGRAM_CODE` | Same `program_code` used in every `*.tfvars` (e.g. `dap`) |

**Environments**: create `tools`, `dev`, `test`, `prod` in Settings → Environments. Add required reviewers to `test` and `prod` — this is the approval gate for production deploys.

**Per-environment Variables** (in each Environment's settings):

| Variable | Value |
|---|---|
| `AZURE_CLIENT_ID` | From `terraform output uami_client_ids["<env>"]` |
| `AZURE_TENANT_ID` | Entra ID tenant ID |
| `AZURE_SUBSCRIPTION_ID` | Subscription ID for that environment |
| `BASTION_RESOURCE_ID` | Resource ID of the tools Bastion host |
| `JUMPBOX_RESOURCE_ID` | Resource ID of the tools jumpbox VM |

---

## CI/CD

```
PR opened  →  pr-validate.yml  →  lint + detect-changes + terraform plan
Merge      →  deploy.yml       →  detect-changes + terraform apply
```

**What triggers a re-plan:**
- `modules/` or `stacks/tenant/` changed → re-plan/apply all tenants in all environments.
- Otherwise → only tenants whose `params/<env>/tenants/<tenant>/` changed.
- `modules/`, `stacks/shared/`, or `params/global/fabric-capacities.yaml` changed → re-plan/apply `stacks/shared` in all environments.

**Bastion proxy**: every plan/apply job opens a SOCKS5 tunnel via the tools Bastion jumpbox (`scripts/bastion-proxy.sh`) so Terraform can reach private storage account endpoints. The tunnel is always closed at the end of the job.

**Approval gates**: when a job targets the `test` or `prod` GitHub Environment, GitHub pauses it for reviewer approval before `terraform apply` runs.

---

## Naming conventions

Azure resource names follow the pattern `<type>-<ministry>-<program_or_tenant>-[subprogram-]<env>`.

**Platform-level resources** (identities, state storage, shared capacities) use `ministry_code` and `program_code`:

| Resource | Example (`ministry=citz`, `program=dap`) |
|---|---|
| State storage account | `stcitzdapdevtfstate` |
| Identity RG | `rg-citz-dap-identity` |
| UAMI | `uami-citz-dap-dev` |
| Shared capacity | `fc-citz-dap-shared-cross-env` |

**Tenant-level resources** use `tenant_name` (and optional `tenant_program_name`) in place of the program segment:

| Resource | Example (`ministry=citz`, `tenant=tenant-tmp`) |
|---|---|
| Platform RG | `rg-citz-tenant-tmp-dev` |
| Workspace RG | `rg-citz-tenant-tmp-dev-ws` |
| Key Vault | `kv-citz-tenant-tmp-dev` |
| KV private endpoint | `pe-kv-citz-tenant-tmp-dev` |
| State blob key | `tenant/tenant-tmp.tfstate` (in `stcitzdapdevtfstate`) |

`tenant_name` must use only lowercase alphanumeric characters and hyphens — Key Vault names don't allow underscores.

---

## Troubleshooting

**`Error acquiring the state lock`** — another CI job holds the lock, or a previous run crashed without releasing it. Check running Actions jobs. If none, break the lease on the relevant `.tfstate` blob in the state storage account via Portal or `az storage blob lease break`.

**`insufficient permissions` on state storage** — the UAMI lacks `Storage Blob Data Contributor` on its own state account, or `Storage Blob Data Reader` on tools' state (needed when `create_dedicated_capacity = false`). Re-apply `stacks/bootstrap/identity` — all role assignments are idempotent.

**Bastion proxy step times out** — the jumpbox VM is probably deallocated (stopped overnight). Start it:

```bash
az vm start \
  --subscription ffc5e617-7f2d-4ddb-8b57-33fc43989a8c \
  --resource-group EO-DMI-ALZ-BASTION-JUMPBOX-TOOLS \
  --name eo-dmi-alz-bastion-jumpbox-jumpbox
```

The Bastion host itself may also have been deleted by the nightly automation runbook. If so, trigger the `Create-BastionHost` runbook manually in the Azure Automation account (`eo-dmi-alz-bastion-jumpbox-jumpbox-automation` in the tools subscription).

**Private endpoint not resolving** — `private_dns_zone_ids` is empty (default), which assumes ALZ DINE policy auto-registers private endpoints. If that policy is not assigned to the subscription, populate `private_dns_zone_ids` in `params/global/network-reference.yaml` and copy the values into the relevant `*.tfvars` files, then re-apply.

**`azurerm_fabric_capacity` not found / provider error** — the `azurerm ~> 4.0` constraint may pin a version without this resource. Upgrade the constraint or switch `modules/fabric-capacity/main.tf` to `azapi_resource` targeting `Microsoft.Fabric/capacities@2023-11-01`.
