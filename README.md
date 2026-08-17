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
│   └── tenant/             # Per-tenant, per-env: KV + PE + optional dedicated capacity
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

Tenants can use either a **3-env pattern** (dev → test → prod) or a **2-env pattern** (dev → prod, skipping test). The pipeline discovers whatever environments are present under `params/` — simply omit the `params/test/tenants/<tenant>/` directory for a 2-env tenant. Both patterns use the same promotion flow; see [Promoting a tenant](#promoting-a-tenant) below.

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

# NOTE: jumpbox access is NOT configured here. It is granted platform-wide via
# jumpbox_principal_ids in params/global/platform-access.tfvars — see step 2b below.

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

### 2b. Grant the tenant team jumpbox access

The tenant's Key Vault has `public_network_access_enabled = false` and is reachable only
through its private endpoint, so a Key Vault role assignment on its own is not enough — the
team also needs a Bastion tunnel to the shared tools jumpbox. That is granted centrally, not
per-tenant. Add their object IDs to `params/global/platform-access.tfvars`:

```hcl
jumpbox_principal_ids = [
  # ...existing principals...
  "<object-id>", # <name>
]
```

`stacks/platform-access` grants each principal `Virtual Machine User Login` on the jumpbox VM
and `Reader` on the Bastion host. Skipping this step is the most common cause of "I have
Secrets Officer but can't read the vault" — the vault loads in the portal, the secrets list
does not.

### 3. Open a PR

```bash
git checkout -b onboard/<tenant>
git add params/dev/tenants/<tenant>/ params/global/platform-access.tfvars
git commit -m "onboard <tenant> to dev"
git push origin onboard/<tenant>
# open PR on GitHub
```

`pr-validate.yml` detects the new directory and runs `terraform plan`. Review the plan in the PR checks — it should show 3 resources: platform RG, Key Vault, and KV private endpoint, plus one role assignment per `kv_rbac_assignments` entry.

### 4. Merge

`deploy.yml` applies the plan. Once both the tenant stack and `stacks/platform-access` have applied, the tenant team can reach their Key Vault via the Bastion jumpbox tunnel.

---

## Promoting a tenant

Promotion is just copying `tenant.tfvars` to the next environment. Each environment has its own state file, so onboarding or changing one tenant never re-plans another.

### 3-env pattern (dev → test → prod)

Use this when the tenant wants a dedicated test environment for pre-production validation.

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

You can promote dev→test and test→prod in the same PR, or in separate PRs. Separate PRs give you a natural gate.

### 2-env pattern (dev → prod, skipping test)

Use this when a tenant treats dev as their non-prod environment and doesn't need a separate test stage. Simply skip the test directory entirely and promote dev directly to prod.

```bash
# Dev → prod (skip test)
cp -r params/dev/tenants/<tenant> params/prod/tenants/<tenant>
sed -i '' 's/environment = "dev"/environment = "prod"/' \
    params/prod/tenants/<tenant>/tenant.tfvars
```

The tenant's Azure resources will be named `*-dev` (non-prod) and `*-prod`. The pipeline detects only the environments that have a `tenant.tfvars` present — no code changes are needed to use this pattern.

### Approval gates

The `prod` GitHub Environment has required reviewers — the apply job pauses for approval before `terraform apply` runs. The `test` environment also has required reviewers if you are using the 3-env pattern.

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

  shared-dev:         # new — usable by all dev tenants
    scope: shared-env
    home_env: tools
    sku: F8
    administrator_members:
      - "first.last@gov.bc.ca"   # UPN, NOT an object ID
```

The logical key becomes the Azure name as `fc<ministry><program><key>` with hyphens stripped — `shared-dev` gives `fccitzdapshareddev`. A capacity belonging to a single tenant can set `name_override` to be named after the tenant instead; see the header of `fabric-capacities.yaml`.

Prefer `home_env: tools` for any capacity spanning environments. A referencing tenant reads that environment's `stacks/shared` state, and every UAMI already has `Storage Blob Data Reader` on the tools state account — homing elsewhere needs a new cross-subscription grant in `stacks/bootstrap/identity`.

To have a tenant use the new capacity, update their `tenant.tfvars` with `fabric_capacity_name = "shared-dev"` — that PR must be merged **after** the capacity exists, since `deploy.yml` runs `apply-shared` and `apply-tenants` in parallel.

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

### Step 0 — Register resource providers (once per subscription)

Azure blocks resource creation in a namespace the subscription has never used. The azurerm provider auto-registers a "core" set, but **`Microsoft.Fabric` is not in it** — so without this, capacity creation fails with:

```
409 Conflict — MissingSubscriptionRegistration: The subscription is not
registered to use namespace 'Microsoft.Fabric'
```

That surfaces *mid-apply*, after the resource group and Key Vault are already created, leaving a half-built tenant that needs a re-run. Register up front, for every subscription:

```bash
for SUB in <tools-sub> <dev-sub> <test-sub> <prod-sub>; do
  for NS in Microsoft.Fabric Microsoft.KeyVault Microsoft.Network \
            Microsoft.Storage Microsoft.ManagedIdentity; do
    az provider register --namespace "$NS" --subscription "$SUB"
  done
done
```

Registration is asynchronous and idempotent — re-running it on an already-registered namespace is a no-op. Confirm all four before continuing; it usually takes 1–3 minutes:

```bash
for SUB in <tools-sub> <dev-sub> <test-sub> <prod-sub>; do
  echo "--- $SUB ---"
  az provider list --subscription "$SUB" \
    --query "[?namespace=='Microsoft.Fabric'].{ns:namespace,state:registrationState}" -o table
done
```

Only `Microsoft.Fabric` genuinely needs this today — the others are in the provider's core set and are listed so a brand-new subscription is covered explicitly. This is deliberately a manual step rather than Terraform: `azurerm_resource_provider_registration` **unregisters the namespace subscription-wide on destroy**, which would affect Fabric capacities owned outside this repo, and `resource_providers_to_register` in the provider block would re-check on every apply.

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

**Private endpoint not resolving** — `private_dns_zone_ids` is empty (default), which assumes ALZ DINE policy auto-registers private endpoints. The policy creates a `deployedByPolicy` zone group on the endpoint, asynchronously — expect a lag of minutes after the apply. Check with:

```bash
az network private-endpoint dns-zone-group list \
  --endpoint-name pe-kv-<ministry>-<tenant>-<env> -g rg-<ministry>-<tenant>-<env> -o table
```

If nothing appears after ~30 minutes, the policy likely isn't assigned at a scope covering that subscription — it is confirmed working in all four (tools, dev, test, prod). Ask the platform team to extend the assignment, or register the endpoint manually. Note that `modules/private-endpoint` sets `ignore_changes = [private_dns_zone_group]`, so populating `private_dns_zone_ids` has **no effect on an existing endpoint**.

**`MissingSubscriptionRegistration` / 409 creating a Fabric capacity** — the subscription has never used `Microsoft.Fabric`, which is not in the azurerm provider's auto-registered "core" set. See [Step 0](#step-0--register-resource-providers-once-per-subscription). Register, wait for `Registered`, then re-run the failed job — resources created before the failure are already in state, so the re-run only adds the capacity.

**`All provided principals must be existing, user or service principals`** — `administrator_members` / `fabric_capacity_admins` was given an object ID. Fabric capacity admins must be **UPNs** (`first.last@gov.bc.ca`), unlike `jumpbox_principal_ids` and `kv_rbac_assignments`, which take object IDs. `terraform plan` cannot catch this; it only fails at apply.

**`azurerm_fabric_capacity` not found / provider error** — the `azurerm ~> 4.0` constraint may pin a version without this resource. Upgrade the constraint or switch `modules/fabric-capacity/main.tf` to `azapi_resource` targeting `Microsoft.Fabric/capacities@2023-11-01`.
