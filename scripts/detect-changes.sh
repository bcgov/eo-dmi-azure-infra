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
  TENANTS_JSON=$(grep -oE '^params/[^/]+/tenants/[^/]+/tenant\.tfvars' <<<"$CHANGED" \
    | awk -F/ '{printf "{\"env\":\"%s\",\"tenant\":\"%s\"}\n", $2, $4}' \
    | jq -s -c . || echo '[]')
fi

if grep -qE '^(modules/|stacks/shared/|params/global/fabric-capacities\.yaml)' <<<"$CHANGED"; then
  SHARED_JSON='["tools","dev","test","prod"]'
else
  SHARED_JSON=$(grep -oE '^params/[^/]+/shared\.tfvars' <<<"$CHANGED" \
    | awk -F/ '{print $2}' | sort -u | jq -R -s -c 'split("\n")[:-1]' || echo '[]')
fi

echo "tenants=${TENANTS_JSON}" >> "$GITHUB_OUTPUT"
echo "shared=${SHARED_JSON}" >> "$GITHUB_OUTPUT"

echo "Changed tenant stacks: ${TENANTS_JSON}"
echo "Changed shared stacks: ${SHARED_JSON}"
