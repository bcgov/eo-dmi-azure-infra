# Platform Guide

Operational reference for the BC Gov Fabric platform infrastructure team.
Covers repo layout, module/stack details, and step-by-step how-tos for
bootstrapping, onboarding tenants, and managing Fabric capacities.

---

## Table of contents

1. [Repo layout explained](#1-repo-layout-explained)
2. [Module reference](#2-module-reference)
3. [Stack reference](#3-stack-reference)
4. [Params reference](#4-params-reference)
5. [CI/CD pipeline overview](#5-cicd-pipeline-overview)
6. [Naming conventions](#6-naming-conventions)
7. [How-to: fill in TODOs before first deploy](#7-how-to-fill-in-todos-before-first-deploy)
8. [How-to: one-time bootstrap](#8-how-to-one-time-bootstrap)
9. [How-to: configure GitHub after bootstrap](#9-how-to-configure-github-after-bootstrap)
10. [How-to: onboard a new tenant](#10-how-to-onboard-a-new-tenant)
11. [How-to: promote a tenant to test/prod](#11-how-to-promote-a-tenant-to-testprod)
12. [How-to: give a tenant a dedicated Fabric capacity](#12-how-to-give-a-tenant-a-dedicated-fabric-capacity)
13. [How-to: add a new shared Fabric capacity](#13-how-to-add-a-new-shared-fabric-capacity)
14. [Troubleshooting](#14-troubleshooting)

---

## 1. Repo layout explained

```
eo-dmi-azure-infra/
│
├── modules/              # Reusable Terraform building blocks.
│   │                     # Called by stacks - never deployed on their own.
│   ├── tenant-platform-rg/
│   ├── workspace-rg/
│   ├── key-vault/
│   ├── private-endpoint/
│   ├── fabric-capacity/
│   ├── uami-federated/
│   └── tfstate-backend/
│
├── stacks/               # Deployable Terraform root modules.
│   │                     # Each has its own backend.tf (separate state file).
│   ├── bootstrap/
│   │   ├── pe-subnet/      # Run once per subscription - adds PE subnet to existing platform spoke VNet.
│   │   ├── state-backend/  # Run once per subscription - creates state storage.
│   │   └── identity/       # Run once in tools - creates all 4 UAMIs + RBAC.
│   ├── shared/             # Per-env shared Fabric capacities.
│   └── tenant/             # Per-tenant, per-env: KV + PE + workspace + capacity.
│
├── params/               # Environment- and tenant-specific variable values.
│   │                     # Changing a file here is what triggers a CI deploy.
│   ├── global/
│   │   ├── fabric-capacities.yaml   # Registry of shared/cross-env capacities.
│   │   └── network-reference.yaml   # Existing VNet/subnet resource IDs (fill in once).
│   ├── bootstrap/
│   │   ├── tools.tfvars             # For stacks/bootstrap/state-backend (tools sub)
│   │   ├── dev.tfvars               # For stacks/bootstrap/state-backend (dev sub)
│   │   ├── test.tfvars
│   │   ├── prod.tfvars
│   │   ├── identity.tfvars          # For stacks/bootstrap/identity (all 4 subs + GitHub refs)
│   │   ├── test-pe-subnet.tfvars    # For stacks/bootstrap/pe-subnet (test sub)
│   │   └── prod-pe-subnet.tfvars    # For stacks/bootstrap/pe-subnet (prod sub)
│   ├── tools/
│   │   └── shared.tfvars            # stacks/shared vars for tools env
│   ├── dev/
│   │   ├── shared.tfvars            # stacks/shared vars for dev env
│   │   └── tenants/
│   │       └── <tenant>/
│   │           └── tenant.tfvars    # stacks/tenant vars for this tenant in dev
│   ├── test/
│   │   └── ...                      # same structure as dev/
│   └── prod/
│       └── ...
│
├── scripts/
│   ├── bastion-proxy.sh    # Opens/closes SOCKS5 tunnel via the tools Bastion jumpbox.
│   └── detect-changes.sh   # Finds which tenants/envs changed in a given git diff.
│
└── .github/workflows/
    ├── .lint.yml            # Reusable: fmt-check + validate + tflint + checkov.
    ├── .detect-changes.yml  # Reusable: runs detect-changes.sh, outputs JSON arrays.
    ├── .plan-apply.yml      # Reusable: terraform init + plan (+ optional apply) via Bastion.
    ├── pr-validate.yml      # Triggered on PRs: lint + detect-changes + plan.
    └── deploy.yml           # Triggered on merge to main: detect-changes + apply.
```

### Key organizing principle

**Params are the source of truth for what is deployed.** The stacks and
modules contain logic; the params files contain values. To deploy something
new (a tenant, a capacity, a promotion), you add or edit a file under
`params/`, open a PR, and the CI picks up exactly what changed.

---

## 2. Module reference

Modules are building blocks that stacks compose. They do not have their own
backend state - they share the state of whichever stack calls them.

### `modules/tenant-platform-rg`

Creates the Terraform-managed resource group for a tenant in a given
environment: `rg-<ministry>-<tenant>-[tenant_program-]<env>` (see
[Naming conventions](#6-naming-conventions) — tenant-level convention,
not the platform `program_code` one).

| Variable | Required | Description |
|---|---|---|
| `ministry_code` | yes | Short BC Gov ministry code, e.g. `"citz"` |
| `tenant_name` | yes | Short tenant identifier, e.g. `"pmt"` |
| `tenant_program_name` | no | Optional sub-program segment, e.g. `"pdt"` — omitted from the name if null |
| `environment` | yes | `tools`, `dev`, `test`, or `prod` |
| `location` | yes | Azure region |
| `tags` | no | Common tags map |

**Output**: `name` (the resource group name).

---

### `modules/workspace-rg`

Creates the self-service resource group `rg-<ministry>-<tenant>-[tenant_program-]<env>-ws`
(the `-ws` suffix distinguishes it from the platform RG, which otherwise has
identical naming segments) and grants `Contributor` to the tenant's Entra ID
group. Terraform never models what goes inside — tenants deploy their own
resources here.

**What Contributor on the workspace RG allows:**
The tenant team can create, update, and delete any Azure resource inside this
RG (e.g. their own pipelines, storage, compute). They cannot assign roles to
others — that requires Owner or User Access Administrator, which is intentionally
not granted.

**To add or remove people from workspace RG access:**
Add/remove them from the Entra group whose object ID is set as
`workspace_owners_group_object_id` in `params/<env>/tenants/<tenant>/tenant.tfvars`.
No Terraform changes are needed — Terraform assigns the role to the group;
group membership is managed separately in Entra ID (Azure Portal → Entra ID →
Groups → find the group → Members).

| Variable | Required | Description |
|---|---|---|
| `ministry_code` | yes | Short BC Gov ministry code, e.g. `"citz"` |
| `tenant_name` | yes | Short tenant identifier |
| `tenant_program_name` | no | Optional sub-program segment, e.g. `"pdt"` — omitted from the name if null |
| `environment` | yes | `dev`, `test`, or `prod` |
| `location` | yes | Azure region |
| `workspace_owners_group_object_id` | yes | Object ID of the tenant team's Entra ID group |
| `role_definition_name` | no | Role to grant on the workspace RG. Default: `Contributor`. Change to `Reader` for read-only, or `Owner` if the team needs to manage role assignments within the RG (not recommended). |
| `tags` | no | Common tags map |

---

### `modules/key-vault`

Creates a private, RBAC-authorized Key Vault (named by the caller as
`kv-<ministry>-<tenant>-[tenant_program-]<env>`, see [Naming conventions](#6-naming-conventions))
inside the platform RG. Public network access is disabled. Purge protection
and 90-day soft-delete are on by default.

| Variable | Required | Description |
|---|---|---|
| `name` | yes | Key Vault name (globally unique across Azure) |
| `resource_group_name` | yes | Platform RG (from `tenant-platform-rg`) |
| `location` | yes | Azure region |
| `tenant_id` | yes | Entra ID tenant ID for RBAC authorization |
| `sku_name` | no | `"standard"` (default) or `"premium"` |
| `purge_protection_enabled` | no | default `true` |
| `soft_delete_retention_days` | no | default `90` |
| `rbac_assignments` | no | List of `{role_definition_name, principal_id}` to grant on this KV |
| `tags` | no | Common tags map |

**Output**: `id` (resource ID), `uri` (vault URI).

---

### `modules/private-endpoint`

Creates a private endpoint into the **existing** shared `snet-pe` subnet
for the environment. Optionally creates a DNS zone group if
`private_dns_zone_ids` is non-empty; otherwise assumes ALZ DINE policy
auto-registers the endpoint.

| Variable | Required | Description |
|---|---|---|
| `name` | yes | PE name, e.g. `"pe-kv-citz-pmt-dev"` |
| `resource_group_name` | yes | RG where the PE lands |
| `location` | yes | Azure region |
| `subnet_id` | yes | ID of the shared PE subnet (from `params/<env>/shared.tfvars`) |
| `target_resource_id` | yes | Resource ID of the resource being connected |
| `subresource_names` | yes | Sub-resource type, e.g. `["vault"]` or `["blob"]` |
| `private_dns_zone_ids` | no | DNS zone IDs for auto-registration. Leave `[]` if ALZ handles it |
| `tags` | no | Common tags map |

---

### `modules/fabric-capacity`

Creates a Microsoft Fabric capacity (named by the caller as
`fc-<ministry>-<tenant>-[tenant_program-]<env>` for a dedicated capacity, or
`fc-<ministry>-<program>-<logical-name>` for a shared one — see
[Naming conventions](#6-naming-conventions)).
Uses `azurerm_fabric_capacity` — verify the pinned `~> 4.0` provider
version includes this resource before first deploy (see
[README known TODOs](../README.md#known-todos-before-first-deploy)).

| Variable | Required | Description |
|---|---|---|
| `name` | yes | Capacity name |
| `resource_group_name` | yes | RG the capacity lives in |
| `location` | yes | Azure region |
| `sku_name` | yes | Fabric SKU, e.g. `"F2"`, `"F8"`, `"F64"` |
| `administrator_members` | yes | UPNs or object IDs of capacity administrators |
| `tags` | no | Common tags map |

**Output**: `id` (resource ID).

---

### `modules/uami-federated`

Creates a User-Assigned Managed Identity (UAMI) and attaches one or more
GitHub OIDC federated credentials to it. All 4 platform UAMIs (named
`uami-<ministry>-<program>-<env>`, see [Naming conventions](#6-naming-conventions))
are created by `stacks/bootstrap/identity` using this module.

| Variable | Required | Description |
|---|---|---|
| `name` | yes | UAMI name, e.g. `"uami-citz-pmt-dev"` |
| `resource_group_name` | yes | RG to put the UAMI in |
| `location` | yes | Azure region |
| `federated_credentials` | yes | List of `{name, subject}` — each `subject` is a GitHub OIDC claim |
| `tags` | no | Common tags map |

**Output**: `client_id`, `principal_id` (object ID), `id`.

---

### `modules/tfstate-backend`

Creates a private storage account (named by the caller as
`st<ministry><program><env>tfstate`, see [Naming conventions](#6-naming-conventions))
and blob container (`tfstate`) for Terraform remote state, with a private
endpoint into the shared PE subnet. Used only by `stacks/bootstrap/state-backend`.

| Variable | Required | Description |
|---|---|---|
| `resource_group_name` | yes | Name of the RG to create (`rg-<ministry>-<program>-tfstate-<env>`) |
| `location` | yes | Azure region |
| `storage_account_name` | yes | Globally unique name (lowercase alphanumeric, max 24 chars) |
| `account_replication_type` | no | Default `"GRS"` |
| `subnet_id` | yes | Shared PE subnet resource ID |
| `private_dns_zone_ids` | no | DNS zone IDs. Leave `[]` if ALZ handles it |
| `tags` | no | Common tags map |

---

## 3. Stack reference

Stacks are the deployable root modules. Each has its own `backend.tf`
(separate `.tfstate` file) so that changes to one stack never re-plan another.

### `stacks/bootstrap/pe-subnet`

**Run once per subscription** when the platform spoke VNet already exists but
has no PE subnet. This is the case for test and prod in this project whose
VNets are VWAN-connected and managed by the BC Gov platform team.

- Looks up the existing VNet via a `data` source — does not touch the VNet itself
- Creates `privateendpoints-subnet` with `private_endpoint_network_policies = Disabled`
- CIDR convention: first `/27` of the VNet's address space

After apply, copy the `subnet_id` output into `params/global/network-reference.yaml`,
`params/bootstrap/<env>.tfvars`, and `params/<env>/shared.tfvars`.

Params: `params/bootstrap/test-pe-subnet.tfvars` / `params/bootstrap/prod-pe-subnet.tfvars`

---

### `stacks/bootstrap/state-backend`

**Run once per subscription** by a platform team member with Owner rights.
Creates the private storage account used as the Terraform remote backend
for all subsequent stacks in that subscription.

- RG: `rg-<ministry>-<program>-tfstate-<env>`
- Storage account: `st<ministry><program><env>tfstate`
- Container: `tfstate`
- PE: into `snet-pe` for private blob access

Starts on **local state**. After it runs, you can optionally migrate state
into the storage account it just created (see `backend.tf` in the stack).

Params: `params/bootstrap/<env>.tfvars` (includes `ministry_code`/`program_code` —
must match `params/bootstrap/identity.tfvars`, since `stacks/bootstrap/identity`
computes the same storage account names to grant RBAC on them)

---

### `stacks/bootstrap/identity`

**Run once, into tools**, by a platform team member.
Creates `rg-<ministry>-<program>-identity` and 4 UAMIs
(`uami-<ministry>-<program>-tools/dev/test/prod`), all homed in the tools
subscription for central management. Each UAMI gets:

- `Contributor` + `Role Based Access Control Administrator` on its **own** subscription
- `Storage Blob Data Contributor` on its **own** env's state storage account
- `Storage Blob Data Reader` on **tools'** state storage account (needed for cross-env
  capacity lookups via `terraform_remote_state`)
- `Reader` + `Virtual Machine User Login` on the tools Bastion + jumpbox VM
- Three GitHub OIDC federated credentials (for its GitHub Environment, for `refs/heads/main`,
  and for pull requests)

Params: `params/bootstrap/identity.tfvars`

After this stack runs, CI is self-sufficient — no service principals, no stored keys.

---

### `stacks/shared`

**Per-environment** stack that creates shared Fabric capacities from the
registry in `params/global/fabric-capacities.yaml`. Only entries with
`home_env` matching the target environment are deployed.

- RG: `rg-<ministry>-<program>-shared-<env>` (created only if there are capacities for that env)
- Capacity name: `fc-<ministry>-<program>-<logical-name>` (the logical name is the YAML key, e.g. `shared-cross-env`)
- State key: `shared/<env>.tfstate`

The default `shared-cross-env` (F64, homed in tools) means this stack
deploys something only in the `tools` environment.

Params: `params/<env>/shared.tfvars`

---

### `stacks/tenant`

**Per-tenant, per-environment** stack. A single invocation creates all the
resources for one tenant in one environment:

| Resource | Name | Notes |
|---|---|---|
| Platform RG | `rg-<ministry>-<tenant>-[tenant_program-]<env>` | Holds all Terraform-managed resources |
| Key Vault | `kv-<ministry>-<tenant>-[tenant_program-]<env>` | Private, RBAC-auth, in platform RG |
| KV Private Endpoint | `pe-kv-<ministry>-<tenant>-[tenant_program-]<env>` | Into shared `snet-pe` |
| Workspace RG | `rg-<ministry>-<tenant>-[tenant_program-]<env>-ws` | Empty; tenant team gets Contributor |
| Dedicated Fabric capacity | `fc-<ministry>-<tenant>-[tenant_program-]<env>` | Only if `create_dedicated_capacity = true` |
| Jumpbox VM Login | *(role assignment on shared VM)* | Grants `Virtual Machine User Login` to `workspace_owners_group_object_id` on the shared Bastion jumpbox so the tenant team can tunnel to their private endpoints. VM managed in `bcgov/eo-dmi-alz-bastion-jumpbox`; VM ID supplied via `jumpbox_vm_id` in `params/<env>/shared.tfvars`. **Temporarily commented out** in `stacks/tenant/main.tf` — requires `stacks/bootstrap/identity` to be re-applied with the `jumpbox_rbac_admin` assignments first (see §8b and §10 Step 4 note). |

`tenant_program_name` (the optional `[tenant_program-]` segment) is set
per-tenant in `tenant.tfvars` — see [Naming conventions](#6-naming-conventions).
`program_code` (the platform's own program code) is still required by this
stack, but only to locate `stacks/shared`'s remote state — it does not
appear in any of the names above.

If the tenant uses a shared capacity (`create_dedicated_capacity = false`),
the stack resolves the capacity's resource ID via `data.terraform_remote_state`
reading `stacks/shared`'s state — no extra CI plumbing needed.

State key: `tenant/<tenant>.tfstate` (per-env state storage account, so
`tenant/tenant-tmp.tfstate` in `stcitzdapdevtfstate` for dev — using the actual
`ministry_code=citz`, `program_code=dap` values).

Params: `params/<env>/shared.tfvars` + `params/<env>/tenants/<tenant>/tenant.tfvars`

---

## 4. Params reference

### `params/global/network-reference.yaml`

Read-only lookup of the **existing** VNet resources managed by the platform
team. Never changed by Terraform. Fill this in once with real resource IDs
(see [How-to §7](#7-how-to-fill-in-todos-before-first-deploy)) and it stays
stable — all tenants in an environment share the same PE subnet.

Fields per environment: `spoke_resource_group`, `spoke_vnet_name`,
`pe_subnet_id`, `private_dns_zone_ids`.

### `params/global/fabric-capacities.yaml`

Registry of shared Fabric capacities. Consumed by `stacks/shared`. Add
entries here to create new shared capacities. Keys are **logical names**
(e.g. `shared-cross-env`) — `stacks/shared` builds the actual Azure resource
name as `fc-<ministry>-<program>-<key>`. Reference a capacity from a
tenant's `tenant.tfvars` by its logical key. Scopes:

| Scope | Meaning |
|---|---|
| `shared-cross-env` | One capacity usable by tenants in any environment. Homed in tools. |
| `shared-env` | One capacity per environment for all tenants in that env. |
| `dedicated` | Documentation-only entry — created by `stacks/tenant` directly. |

### `params/bootstrap/*.tfvars`

One-time bootstrap inputs (subscription IDs, subnet IDs, GitHub org/repo,
Bastion/jumpbox resource IDs, plus `ministry_code`/`program_code`). Filled
in once; rarely changed. `ministry_code`/`program_code` must be identical
across all 5 files (`tools.tfvars`, `dev.tfvars`, `test.tfvars`,
`prod.tfvars`, `identity.tfvars`) — `stacks/bootstrap/identity` computes the
same state storage account names as `stacks/bootstrap/state-backend` to
grant RBAC on them, so a mismatch breaks that lookup.

### `params/<env>/shared.tfvars`

Per-environment inputs for `stacks/shared` (and re-used by `stacks/tenant`
for networking and naming values): `environment`, `ministry_code`,
`program_code`, `subscription_id`, `location`, `azure_tenant_id`,
`pe_subnet_id`, `private_dns_zone_ids`, `jumpbox_vm_id`, `tags`.

`jumpbox_vm_id` is the resource ID of the shared Bastion jumpbox VM
(`bcgov/eo-dmi-alz-bastion-jumpbox`). It is the same value across all
environments since there is one shared jumpbox. Every tenant deployed
by `stacks/tenant` receives `Virtual Machine User Login` on this VM.

### `params/<env>/tenants/<tenant>/tenant.tfvars`

The onboarding record for one tenant in one environment. Contains:

| Field | Description |
|---|---|
| `tenant_name` | Short identifier (used in all resource names) |
| `tenant_program_name` | *(optional)* Sub-program segment added to every resource name if set — see [Naming conventions](#6-naming-conventions) |
| `environment` | Must match the directory env |
| `workspace_owners_group_object_id` | Entra ID group object ID for the tenant's workspace RG |
| `kv_rbac_assignments` | Roles to grant on the tenant's Key Vault |
| `create_dedicated_capacity` | `true` to create a dedicated Fabric capacity; `false` to use shared |
| `fabric_capacity_name` | Logical key from `fabric-capacities.yaml` when using shared (e.g. `"shared-cross-env"`, not the Azure resource name) |
| `dedicated_capacity_sku` | Fabric SKU if `create_dedicated_capacity = true` |
| `fabric_capacity_admins` | Admin UPNs/object IDs for a dedicated capacity |
| `tags` | Tenant-specific tags (at minimum `{ tenant = "<name>" }`) |

---

## 5. CI/CD pipeline overview

```
PR opened
  └── pr-validate.yml
        ├── .lint.yml            (fmt-check, validate, tflint, checkov)
        ├── .detect-changes.yml  (which tenants/envs changed vs base SHA)
        ├── plan-tenants         (matrix: stacks/tenant × changed {env,tenant})
        └── plan-shared          (matrix: stacks/shared × changed envs)

Merge to main
  └── deploy.yml
        ├── .detect-changes.yml  (changed since previous push SHA)
        ├── apply-tenants        (matrix: same as above, apply: true)
        └── apply-shared         (matrix: same, apply: true)
```

**Change detection logic** (`scripts/detect-changes.sh`):
- If `modules/` or `stacks/tenant/` changed → re-plan/apply ALL tenants in ALL envs.
- Otherwise → only tenants whose `params/<env>/tenants/<tenant>/` changed.
- If `modules/`, `stacks/shared/`, or `params/global/fabric-capacities.yaml` changed → re-plan/apply shared in all envs.
- Otherwise → only envs whose `params/<env>/shared.tfvars` changed.

**Approval gates**: `test` and `prod` GitHub Environments have required-reviewer
rules. When a `stacks/tenant` or `stacks/shared` job targets those environments,
GitHub pauses it for approval before running — no extra code needed.

**Bastion proxy**: every plan/apply job opens a SOCKS5 tunnel via the existing
tools jumpbox (`scripts/bastion-proxy.sh start`) so Terraform can reach private
storage account endpoints. It is always closed at the end (`if: always()`).

---

## 6. Naming conventions

### The standard

Every Azure resource follows the same four-segment shape, but which concept
fills the 2nd/3rd slot depends on whether the resource is **platform-level**
(not tied to one tenant) or **tenant-level** (owned by a specific tenant):

```
<resource-type>-<ministry>-<program>-<subprogram>-<environment>          # platform-level
<resource-type>-<ministry>-<tenant>-<tenant_program>-<environment>       # tenant-level
```

| Segment | Platform-level meaning | Tenant-level meaning |
|---|---|---|
| `resource-type` | Short Azure resource-type prefix (`rg`, `kv`, `pe`, `fc`, `uami`, `st`) | same |
| `ministry` | BC Gov ministry code, e.g. `citz` | same |
| 2nd segment | `program` — the Fabric platform's own program code, e.g. `pmt` (constant across the whole repo) | `tenant_name` — the tenant's own identifier, e.g. `pmt` (a tenant can coincidentally share its name with the platform's program code - they're unrelated values) |
| 3rd segment | `subprogram` — *(optional)* a fixed functional label (`tfstate`, `identity`, `shared`) | `tenant_program_name` — *(optional)* the tenant's own sub-program, e.g. `pdt` |
| `environment` | `tools`/`dev`/`test`/`prod`, omitted if global | same |

In other words: for a tenant's own resources, the tenant *is* the "program"
— each tenant is itself a program/sub-program within the ministry, so its
name occupies the slot a platform-wide program code would otherwise fill.
The platform's own infrastructure (state backend, identities, shared
capacities) isn't tied to any one tenant, so it keeps `program_code` as a
constant in that slot instead.

Two worked examples from the BC Gov request that motivated this convention
(here `pdt` and `wma` are tenant names, occupying the 2nd slot):

```
rg-citz-pdt-dev     # platform RG for tenant "pdt", dev
rg-citz-wma-dev     # platform RG for tenant "wma", dev
```

`ministry_code` and `program_code` are platform-wide constants — used for
every **platform-level** resource name, and still required by `stacks/tenant`
solely to locate `stacks/shared`'s remote state (see
[`stacks/tenant/locals.tf`](../stacks/tenant/locals.tf) — not used in a
tenant's own resource names). They are supplied as Terraform variables, sourced from:

- `params/<env>/shared.tfvars` and every tenant/shared stack run
- `params/bootstrap/*.tfvars` for the bootstrap stacks
- `vars.MINISTRY_CODE` / `vars.PROGRAM_CODE` GitHub Actions variables for CI
  (set these once at the repo level — see [How-to §9](#9-how-to-configure-github-after-bootstrap))

`tenant_name` and the optional `tenant_program_name` are supplied per-tenant
in `params/<env>/tenants/<tenant>/tenant.tfvars`.

**Keep all codes short** (4 characters or fewer recommended) — `ministry_code`/
`program_code` appear in storage account names, which cap at 24 characters
total with no hyphens.

### Resource name reference

**Platform-level** (use `ministry_code`/`program_code`):

| Resource | Pattern | Example (`ministry=citz`, `program=pmt`) |
|---|---|---|
| State storage RG | `rg-<ministry>-<program>-tfstate-<env>` | `rg-citz-pmt-tfstate-dev` |
| State storage account | `st<ministry><program><env>tfstate` | `stcitzpmtdevtfstate` |
| State container | `tfstate` | — |
| Identity RG | `rg-<ministry>-<program>-identity` | `rg-citz-pmt-identity` |
| UAMI | `uami-<ministry>-<program>-<env>` | `uami-citz-pmt-dev` |
| Shared capacity RG | `rg-<ministry>-<program>-shared-<env>` | `rg-citz-pmt-shared-tools` |
| Shared capacity | `fc-<ministry>-<program>-<logical-name>` | `fc-citz-pmt-shared-cross-env` |

**Tenant-level** (use `tenant_name` / optional `tenant_program_name`):

| Resource | Pattern | Example (`ministry=citz`, `tenant=pmt`, no sub-program) |
|---|---|---|
| Tenant platform RG | `rg-<ministry>-<tenant>-[tenant_program-]<env>` | `rg-citz-pmt-dev` |
| Tenant workspace RG | `rg-<ministry>-<tenant>-[tenant_program-]<env>-ws` | `rg-citz-pmt-dev-ws` |
| Key Vault | `kv-<ministry>-<tenant>-[tenant_program-]<env>` | `kv-citz-pmt-dev` |
| KV private endpoint | `pe-kv-<ministry>-<tenant>-[tenant_program-]<env>` | `pe-kv-citz-pmt-dev` |
| Dedicated capacity | `fc-<ministry>-<tenant>-[tenant_program-]<env>` | `fc-citz-pmt-dev` |
| State key (tenant) | `tenant/<tenant>.tfstate` | `tenant/pmt.tfstate` |
| State key (shared) | `shared/<env>.tfstate` | `shared/tools.tfstate` |

With `tenant_program_name = "pdt"` set, the same tenant's platform RG would
be `rg-citz-pmt-pdt-dev` instead — matching the original worked example in
[the standard above](#the-standard).

### What deliberately does NOT follow this convention, and why

| Identifier | Why it's excluded |
|---|---|
| Terraform state **blob keys** (`tenant/<tenant>.tfstate`, `shared/<env>.tfstate`) | These are paths inside a storage account that's *already* named per the convention — the account name carries the ministry/program/env identity. The blob key only needs to distinguish tenants/stacks within that account, the way a file path doesn't repeat its own drive letter. |
| Fabric capacity **logical keys** in `fabric-capacities.yaml` (e.g. `shared-cross-env`) | These are internal lookup keys referenced by `tenant.tfvars`, not Azure resource names — the Azure name is generated from them (see above). Kept short and descriptive for readability in YAML/tfvars. |
| GitHub **Environment names** (`tools`, `dev`, `test`, `prod`) | Fixed, minimal names required by GitHub's environment-protection feature and referenced in UAMI OIDC federated-credential subjects; not Azure resources. |
| GitHub Actions **variable names** (`AZURE_CLIENT_ID`, `MINISTRY_CODE`, etc.) | Configuration inputs, not resources — named per GitHub/Azure tooling convention (`SCREAMING_SNAKE_CASE`). |
| Terraform **module/resource local identifiers** in code (`module "platform_rg"`) | Internal to the `.tf` files, never appear in Azure or any UI a tenant sees. |

### Recommendation (not enforced in code)

The `tags` block in every `*.tfvars` file includes a freeform `ministry`
value (e.g. `tags = { ministry = "<TODO-ministry-code>" }`). Keep this in
sync with `ministry_code` by hand — they are deliberately separate inputs
(tags vs. naming) so this repo doesn't force every consumer to retag
existing resources, but drift between them would be confusing. Consider
adding `program = var.program_code` to the same tags block when you fill
in real values.

---

## 7. How-to: fill in TODOs before first deploy

All `<TODO-...>` placeholders need to be replaced with real values before
any Terraform runs. Do this before bootstrapping.

**Step 1 — look up your subscription IDs** (Azure Portal → Subscriptions):

```
b9cee3-tools = <tools-sub-id>
b9cee3-dev   = <dev-sub-id>
b9cee3-test  = <test-sub-id>
b9cee3-prod  = <prod-sub-id>
```

**Step 2 — look up the existing spoke VNet/subnet resource IDs** for each
environment (Portal → the spoke VNet → Subnets → `snet-pe` → Properties):

Fill in `params/global/network-reference.yaml`:
- `pe_subnet_id` for each env
- `spoke_resource_group` and `spoke_vnet_name` (informational)
- `private_dns_zone_ids`: leave `[]` unless the platform team confirms ALZ
  DINE policy is NOT auto-registering private endpoints for this subscription.

**Step 3 — pick your `ministry_code` and `program_code`** (see
[Naming conventions](#6-naming-conventions); keep both short, 4 characters
or fewer) and set them identically in:
- every `params/<env>/shared.tfvars` (tools/dev/test/prod)
- every `params/bootstrap/*.tfvars` (tools/dev/test/prod + identity.tfvars)
- the GitHub repo's `MINISTRY_CODE` / `PROGRAM_CODE` Actions variables (§9)

**Step 4 — fill in all `params/<env>/shared.tfvars`** (tools/dev/test/prod)
with their respective `subscription_id`, `azure_tenant_id`, and the
`pe_subnet_id` copied from `network-reference.yaml`.

**Step 5 — fill in all `params/bootstrap/*.tfvars`** with the same subscription
IDs plus your Bastion and jumpbox resource IDs from `bcgov/eo-dmi-alz-bastion-jumpbox`:

```hcl
bastion_resource_id    = "/subscriptions/<tools-sub>/resourceGroups/<rg>/providers/Microsoft.Network/bastionHosts/<name>"
jumpbox_vm_resource_id = "/subscriptions/<tools-sub>/resourceGroups/<rg>/providers/Microsoft.Compute/virtualMachines/<name>"
```

**Step 6 — update `params/global/fabric-capacities.yaml`** with the real
admin UPN/object ID for the `shared-cross-env` capacity.

---

## 8. How-to: one-time bootstrap

Run these **locally** as a platform team member with Owner (or Contributor +
User Access Administrator) across all 4 subscriptions. You need the Azure
CLI and Terraform installed, and must be reachable to the Bastion jumpbox
for the dev/test/prod state storage accounts (private endpoints).

### 8a. Create state storage — once per subscription

Run in this order: tools → dev → test → prod.

```bash
cd stacks/bootstrap/state-backend

# For tools:
terraform init   # uses local state initially
terraform apply -var-file=../../../params/bootstrap/tools.tfvars

# Repeat for dev / test / prod:
terraform apply -var-file=../../../params/bootstrap/dev.tfvars
terraform apply -var-file=../../../params/bootstrap/test.tfvars
terraform apply -var-file=../../../params/bootstrap/prod.tfvars
```

After each apply you can optionally migrate state into the backend it just
created — see `stacks/bootstrap/state-backend/backend.tf` for the config.

### 8b. Create UAMIs and RBAC — once, into tools

```bash
cd stacks/bootstrap/identity

terraform init \
  -backend-config=resource_group_name=rg-citz-pmt-tfstate-tools \
  -backend-config=storage_account_name=stcitzpmttoolstfstate \
  -backend-config=container_name=tfstate \
  -backend-config=key=bootstrap/identity.tfstate \
  -backend-config=use_azuread_auth=true
# (substitute your actual ministry_code/program_code for citz/pmt)

terraform apply -var-file=../../../params/bootstrap/identity.tfvars
```

Note the output: `terraform output uami_client_ids` gives you the 4 client
IDs you need for the GitHub configuration step.

### 8c. Create PE subnet — once per subscription (test and prod)

Run this **before** `stacks/bootstrap/state-backend` for any subscription
whose spoke VNet already exists but has no PE subnet (test and prod in this
project). The subnet must exist before state-backend can create its private
endpoint.

```bash
cd stacks/bootstrap/pe-subnet

# For test:
terraform init
terraform apply -var-file=../../../params/bootstrap/test-pe-subnet.tfvars

# For prod:
terraform init
terraform apply -var-file=../../../params/bootstrap/prod-pe-subnet.tfvars
```

The `subnet_id` output is already pre-filled into the relevant params files
(`params/global/network-reference.yaml`, `params/bootstrap/test.tfvars`,
`params/bootstrap/prod.tfvars`, `params/test/shared.tfvars`,
`params/prod/shared.tfvars`). If you re-run against a new environment, copy
the output manually into those files.

### 8d. Bootstrap a brand-new subscription

For a new subscription, the BC Gov platform team provisions the VWAN-connected
spoke VNet. Once that exists, the process is the same as §8c above — run
`stacks/bootstrap/pe-subnet` to add the PE subnet, then continue with
`state-backend` and `identity`.

```bash
# 1. Create a new tfvars file for the new subscription:
cp params/bootstrap/test-pe-subnet.tfvars params/bootstrap/<env>-pe-subnet.tfvars
# Edit: subscription_id, vnet_resource_group, vnet_name, address_prefix
#       (use the first /27 of the VNet's address space)

# 2. Apply:
cd stacks/bootstrap/pe-subnet
terraform init
terraform apply -var-file=../../../params/bootstrap/<env>-pe-subnet.tfvars

# 3. Copy subnet_id from the output into:
#    - params/global/network-reference.yaml  (pe_subnet_id for this env)
#    - params/bootstrap/<env>.tfvars         (subnet_id)
#    - params/<env>/shared.tfvars            (pe_subnet_id)

# 4. Then continue with state-backend and identity as in §8a / §8b.
```

Address space convention (matching existing subscriptions):

| Env | VNet address space | PE subnet |
|-----|--------------------|-----------|
| tools | — | `10.46.10.0/27` (existing, platform-created) |
| dev | — | `10.46.10.0/27` (existing, platform-created) |
| test | `10.46.8.0/24` | `10.46.8.0/27` (created by pe-subnet stack) |
| prod | `10.46.152.0/24` | `10.46.152.0/27` (created by pe-subnet stack) |

For a new subscription, get the VNet address space from the platform team and
use its first `/27` for the PE subnet.

---

## 9. How-to: configure GitHub after bootstrap

Do this once after `stacks/bootstrap/identity` has been applied.

**Set repo-level Variables** (Settings → Secrets and variables → Actions →
Variables, repo tab — not environment tab, since these two are the same in
every environment):

| Variable | Value |
|---|---|
| `MINISTRY_CODE` | The same `ministry_code` used in every `*.tfvars` (e.g. `citz`) |
| `PROGRAM_CODE` | The same `program_code` used in every `*.tfvars` (e.g. `pmt`) |

These are read by `pr-validate.yml`/`deploy.yml` to build the
`backend_config_args` for each plan/apply job — see
[Naming conventions](#6-naming-conventions).

**Create 4 GitHub Environments** in the repo settings: `tools`, `dev`, `test`, `prod`.
- Add required reviewers to `test` and `prod` (this is the approval gate for production deploys).

**For each environment**, set these **Variables** (not Secrets):

| Variable | Value |
|---|---|
| `AZURE_CLIENT_ID` | From `terraform output uami_client_ids["<env>"]` |
| `AZURE_TENANT_ID` | Your Entra ID tenant ID |
| `AZURE_SUBSCRIPTION_ID` | The subscription ID for that environment |
| `BASTION_RESOURCE_ID` | Resource ID of the tools Bastion host |
| `JUMPBOX_RESOURCE_ID` | Resource ID of the tools jumpbox VM |

---

## 10. How-to: onboard a new tenant

This is the steady-state operation — no changes to modules or stacks needed.

### Step 1 — copy the example tenant directory

```bash
cp -r params/dev/tenants/tenant-tmp params/dev/tenants/<tenant>
```

### Step 2 — edit `params/dev/tenants/<tenant>/tenant.tfvars`

```hcl
tenant_name = "<tenant>"
environment = "dev"

# Optional - uncomment to add a sub-program naming segment (see Naming
# conventions): rg-<ministry>-<tenant>-<tenant_program_name>-dev
# tenant_program_name = "pdt"

# Object ID of the Entra ID group that owns this tenant's resources.
# The group must already exist — this repo does not create Entra ID groups.
workspace_owners_group_object_id = "<object-id>"

kv_rbac_assignments = [
  {
    # Key Vault Secrets Officer: allows the tenant team to create, update, and
    # delete secrets. Use this for teams managing their own secrets.
    # Do NOT use Key Vault Administrator - that also controls vault networking
    # and access policy configuration, which is ops-only.
    role_definition_name = "Key Vault Secrets Officer"
    principal_id          = "<object-id>"   # same group as workspace_owners, or a different principal
  }
]

# To use the default shared cross-env capacity (logical key, not the Azure
# resource name - see params/global/fabric-capacities.yaml):
create_dedicated_capacity = false
fabric_capacity_name      = "shared-cross-env"

tags = {
  tenant = "<tenant>"
}
```

### Step 3 — open a PR

```bash
git checkout -b onboard/<tenant>
git add params/dev/tenants/<tenant>/
git commit -m "onboard <tenant> to dev"
git push origin onboard/<tenant>
# open PR
```

`pr-validate.yml` will detect the new tenant directory and run
`terraform plan` for `stacks/tenant` against dev. Review the plan output
in the PR checks — it should show the 4 resources (platform RG, KV, PE,
workspace RG) being created.

### Step 4 — merge

Once the plan looks correct, merge. `deploy.yml` applies the plan and
creates the resources. The tenant team can now access their workspace RG,
Key Vault, and the shared Bastion jumpbox immediately.

> **Note on Bastion access**: the `azurerm_role_assignment` granting
> `Virtual Machine User Login` on the shared jumpbox VM is **currently commented
> out** in `stacks/tenant/main.tf`. Before it can be enabled, the dev/test/prod
> UAMIs must have `Role Based Access Control Administrator` scoped to the jumpbox
> VM (tools subscription). This is already coded in `stacks/bootstrap/identity`
> as `jumpbox_rbac_admin`, but needs to be applied. Re-apply
> `stacks/bootstrap/identity` (§8b), then uncomment the `jumpbox_vm_login`
> block in `stacks/tenant/main.tf`.

---

## 11. How-to: promote a tenant to test/prod

Promotion is just copying `tenant.tfvars` to the next environment. Separate
state files mean there is zero blast radius on dev.

```bash
# Promote to test
cp -r params/dev/tenants/<tenant> params/test/tenants/<tenant>

# Update environment field:
sed -i '' 's/environment = "dev"/environment = "test"/' \
    params/test/tenants/<tenant>/tenant.tfvars

# Repeat for prod:
cp -r params/test/tenants/<tenant> params/prod/tenants/<tenant>
sed -i '' 's/environment = "test"/environment = "prod"/' \
    params/prod/tenants/<tenant>/tenant.tfvars
```

Open a PR with the new files. The CI will plan against test (and prod).
On merge, `deploy.yml` applies — but test and prod GitHub Environments have
required reviewers, so the job will pause for approval before running.

You can promote dev→test and test→prod in the same PR, or in separate PRs.
Using separate PRs gives you a natural gate.

---

## 12. How-to: give a tenant a dedicated Fabric capacity

Edit the tenant's `tenant.tfvars` for the relevant environment:

```hcl
create_dedicated_capacity = true
dedicated_capacity_sku    = "F4"               # choose the right SKU
fabric_capacity_admins    = ["admin@gov.bc.ca"]
# fabric_capacity_name can be removed or left as null when using dedicated
```

Open a PR. The plan will show `fc-<ministry>-<tenant>-[tenant_program-]<env>`
being added inside `rg-<ministry>-<tenant>-[tenant_program-]<env>`. Merge to apply.

To scale the SKU later, just change `dedicated_capacity_sku` in the same
file and PR the change in.

---

## 13. How-to: add a new shared Fabric capacity

Edit `params/global/fabric-capacities.yaml`:

```yaml
capacities:
  shared-cross-env:          # existing
    ...

  shared-dev:                # new: a capacity homed in dev for all dev tenants
    scope: shared-env
    home_env: dev
    sku: F8
    administrator_members:
      - "fabric-platform-admins@gov.bc.ca"
```

The key (`shared-dev`) is a logical name only — `stacks/shared` will create
the Azure resource as `fc-<ministry>-<program>-shared-dev`.

Open a PR. The detect-changes script sees `fabric-capacities.yaml` changed
and queues a plan for `stacks/shared` in **all** environments. Only the `dev`
plan will show any new resources (the others will be no-ops because no capacity
has `home_env: tools/test/prod`).

To have a tenant use the new capacity, update their `tenant.tfvars`:

```hcl
fabric_capacity_name = "shared-dev"
```

That PR must be merged **after** the capacity exists (i.e., after the
`fabric-capacities.yaml` PR is applied).

---

## 14. Troubleshooting

### Plan fails: "Error acquiring the state lock"

Another CI job is holding the state lock (or a previous run crashed without
releasing it). Check running Actions jobs. If no job is running, manually
break the lease on the blob in the state storage account
(`st<ministry><program><env>tfstate` / `tfstate` container / the relevant
`.tfstate` blob) via the Azure Portal or `az storage blob lease break`.

### Plan fails: "insufficient permissions" on the state storage account

The UAMI for that environment does not have `Storage Blob Data Contributor`
on its state storage account, or `Storage Blob Data Reader` on tools' state
storage (needed when `create_dedicated_capacity = false`). Re-run
`stacks/bootstrap/identity` — the role assignments are idempotent.

### Bastion proxy step times out

The jumpbox VM may be deallocated (it can be stopped to save cost). Start it
via the Azure Portal or `az vm start`. The UAMI needs `Virtual Machine User
Login` + `Reader` on the jumpbox — granted by `stacks/bootstrap/identity`.

### Private endpoint not resolving

`private_dns_zone_ids` is empty (default) — this means the repo assumes ALZ
DINE policy auto-registers the PE. If that policy is not assigned to this
subscription, populate `private_dns_zone_ids` in `params/global/network-reference.yaml`
and copy the values into the relevant `*.tfvars` files, then re-apply.

### `azurerm_fabric_capacity` not found / provider error

The `azurerm` provider `~> 4.0` may not include `azurerm_fabric_capacity` in
the version pinned in `stacks/*/providers.tf`. Either upgrade the constraint
or switch `modules/fabric-capacity/main.tf` to use `azapi_resource` targeting
`Microsoft.Fabric/capacities@2023-11-01`.
