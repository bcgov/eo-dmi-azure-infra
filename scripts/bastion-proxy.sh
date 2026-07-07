#!/usr/bin/env bash
# Opens (or closes) a SOCKS5 proxy to the b9cee3-tools jumpbox via Azure
# Bastion's native client tunneling, so a GitHub-hosted runner can reach
# private endpoints (Terraform state storage, Key Vault PEs) with no public
# endpoints and no self-hosted runner. Spoke-to-spoke peering from tools to
# dev/test/prod is already in place, so this single tunnel reaches all
# environments' private endpoints.
#
# This is an adaptation of bastion-proxy.sh from bcgov/eo-dmi-alz-bastion-jumpbox
# - reconcile with that script if its interface changes.
#
# Requires: az CLI (with the `bastion` extension) and an active `az login`
# (done via azure/login OIDC to the per-subscription UAMI before this runs).
#
# Usage:
#   bastion-proxy.sh start   # opens tunnel, appends proxy vars to $GITHUB_ENV
#   bastion-proxy.sh stop    # closes tunnel
#
# Required env vars for "start":
#   BASTION_RESOURCE_ID  - resource ID of the Bastion host in b9cee3-tools
#   JUMPBOX_RESOURCE_ID  - resource ID of the jumpbox VM in b9cee3-tools

set -euo pipefail

ACTION="${1:?usage: bastion-proxy.sh start|stop}"

TUNNEL_PORT="${TUNNEL_PORT:-2222}"
SOCKS_PORT="${SOCKS_PORT:-8228}"
PID_DIR="${RUNNER_TEMP:-/tmp}"
TUNNEL_PID_FILE="${PID_DIR}/bastion-tunnel.pid"
PROXY_PID_FILE="${PID_DIR}/ssh-socks-proxy.pid"

case "$ACTION" in
  start)
    : "${BASTION_RESOURCE_ID:?BASTION_RESOURCE_ID is required}"
    : "${JUMPBOX_RESOURCE_ID:?JUMPBOX_RESOURCE_ID is required}"

    bastion_name=$(basename "$BASTION_RESOURCE_ID")
    bastion_rg=$(sed -E 's#.*/resourceGroups/([^/]+)/.*#\1#' <<<"$BASTION_RESOURCE_ID")

    az extension add --name bastion --upgrade --only-show-errors

    az network bastion tunnel \
      --name "$bastion_name" \
      --resource-group "$bastion_rg" \
      --target-resource-id "$JUMPBOX_RESOURCE_ID" \
      --resource-port 22 \
      --port "$TUNNEL_PORT" \
      >"${PID_DIR}/bastion-tunnel.log" 2>&1 &
    echo $! > "$TUNNEL_PID_FILE"

    # Wait for the local tunnel endpoint to come up.
    for _ in $(seq 1 30); do
      (exec 3<>"/dev/tcp/127.0.0.1/${TUNNEL_PORT}") 2>/dev/null && exec 3>&- && break
      sleep 1
    done

    # Entra ID SSH login (no stored keys, via the AAD SSH login extension on
    # the jumpbox), opened as a local SOCKS5 proxy for Terraform's
    # data-plane traffic (state storage blob API, Key Vault).
    az ssh vm \
      --ip 127.0.0.1 \
      --port "$TUNNEL_PORT" \
      --local-user azureuser \
      -- -D "$SOCKS_PORT" -N -f \
      >"${PID_DIR}/ssh-socks-proxy.log" 2>&1 &
    echo $! > "$PROXY_PID_FILE"

    sleep 5

    {
      echo "ALL_PROXY=socks5h://127.0.0.1:${SOCKS_PORT}"
      echo "HTTPS_PROXY=socks5h://127.0.0.1:${SOCKS_PORT}"
      echo "HTTP_PROXY=socks5h://127.0.0.1:${SOCKS_PORT}"
    } >> "$GITHUB_ENV"
    ;;

  stop)
    [ -f "$PROXY_PID_FILE" ] && kill "$(cat "$PROXY_PID_FILE")" 2>/dev/null || true
    [ -f "$TUNNEL_PID_FILE" ] && kill "$(cat "$TUNNEL_PID_FILE")" 2>/dev/null || true
    rm -f "$PROXY_PID_FILE" "$TUNNEL_PID_FILE"
    ;;

  *)
    echo "usage: bastion-proxy.sh start|stop" >&2
    exit 1
    ;;
esac
