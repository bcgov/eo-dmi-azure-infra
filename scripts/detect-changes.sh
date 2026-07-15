#!/usr/bin/env bash
# Determines which tenant stacks and which environments' shared stacks need
# to be planned/applied for this push or PR, based on changed files.
#
# Writes two JSON values to $GITHUB_OUTPUT:
#   tenants - [{ "env": "dev", "tenant": "pmt" }, ...]
#   shared  - ["dev", "tools", ...]   (environments whose shared stack changed)
#
# A change under modules/ or stacks/tenant/ affects every tenant in every
# environment. A change under modules/, stacks/shared/, or
# params/global/fabric-capacities.yaml affects every environment's shared
# stack.
#
# Usage: detect-changes.sh <base-sha>
set -euo pipefail

BASE_SHA="${1:?base sha required}"

CHANGED=$(git diff --name-only "${BASE_SHA}"...HEAD)

if grep -qE '^(modules/|stacks/tenant/)' <<<"$CHANGED"; then
  TENANTS_JSON=$(find params -mindepth 4 -maxdepth 4 -path '*/tenants/*/tenant.tfvars' \
    | awk -F/ '{printf "{\"env\":\"%s\",\"tenant\":\"%s\"}\n", $2, $4}' \
    | jq -s -c .)
else
  # grep exits 1 (no match) and jq -s -c . on empty input also outputs '[]' —
  # combining them with || causes jq's '[]' AND echo's '[]' to both be captured,
  # producing a two-line value that corrupts $GITHUB_OUTPUT. Separate the grep
  # so we can short-circuit cleanly.
  _tenant_matches=$(grep -oE '^params/[^/]+/tenants/[^/]+/tenant\.tfvars' <<<"$CHANGED" || true)
  if [[ -z "$_tenant_matches" ]]; then
    TENANTS_JSON='[]'
  else
    TENANTS_JSON=$(echo "$_tenant_matches" \
      | awk -F/ '{printf "{\"env\":\"%s\",\"tenant\":\"%s\"}\n", $2, $4}' \
      | jq -s -c .)
  fi
fi

if grep -qE '^(modules/|stacks/shared/|params/global/fabric-capacities\.yaml)' <<<"$CHANGED"; then
  SHARED_JSON='["tools","dev","test","prod"]'
else
  _shared_matches=$(grep -oE '^params/[^/]+/shared\.tfvars' <<<"$CHANGED" || true)
  if [[ -z "$_shared_matches" ]]; then
    SHARED_JSON='[]'
  else
    SHARED_JSON=$(echo "$_shared_matches" \
      | awk -F/ '{print $2}' | sort -u | jq -R -s -c 'split("\n")[:-1]')
  fi
fi

echo "tenants=${TENANTS_JSON}" >> "$GITHUB_OUTPUT"
echo "shared=${SHARED_JSON}" >> "$GITHUB_OUTPUT"

echo "Changed tenant stacks: ${TENANTS_JSON}"
echo "Changed shared stacks: ${SHARED_JSON}"
