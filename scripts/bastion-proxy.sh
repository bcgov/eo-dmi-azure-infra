#!/usr/bin/env bash
# Opens (or closes) a SOCKS5 proxy to the b9cee3-tools jumpbox via Azure
# Bastion's native SSH integration, so a GitHub-hosted runner can reach
# private endpoints (Terraform state storage, Key Vault PEs) with no public
# endpoints and no self-hosted runner. Spoke-to-spoke peering from tools to
# dev/test/prod is already in place, so this single tunnel reaches all
# environments' private endpoints.
#
# This is an adaptation of bastion-proxy.sh from bcgov/eo-dmi-alz-bastion-jumpbox
# - reconcile with that script if its interface changes.
#
# Requires: az CLI (with the `bastion` and `ssh` extensions) and an active
# `az login` (done via azure/login OIDC to the per-subscription UAMI before
# this runs).
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

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

SOCKS_PORT="${SOCKS_PORT:-8228}"
BRIDGE_PORT="${BRIDGE_PORT:-8229}"
PID_DIR="${RUNNER_TEMP:-/tmp}"
PROXY_PID_FILE="${PID_DIR}/ssh-socks-proxy.pid"
BRIDGE_PID_FILE="${PID_DIR}/socks5h-bridge.pid"

case "$ACTION" in
  start)
    : "${BASTION_RESOURCE_ID:?BASTION_RESOURCE_ID is required}"
    : "${JUMPBOX_RESOURCE_ID:?JUMPBOX_RESOURCE_ID is required}"

    bastion_sub=$(sed -E 's#.*/subscriptions/([^/]+)/.*#\1#' <<<"$BASTION_RESOURCE_ID")
    bastion_name=$(basename "$BASTION_RESOURCE_ID")
    bastion_rg=$(sed -E 's#.*/resourceGroups/([^/]+)/.*#\1#' <<<"$BASTION_RESOURCE_ID")

    az extension add --name ssh --upgrade --only-show-errors
    az extension add --name bastion --upgrade --only-show-errors

    # `az network bastion ssh` handles the Bastion WebSocket tunnel AND AAD SSH
    # auth in a single command. --auth-type "AAD" authenticates using the current
    # az login identity (the per-subscription UAMI) via the AADSSHLoginForLinux
    # extension on the jumpbox — no stored SSH keys required.
    #
    # --subscription is required when the OIDC login is scoped to a different
    # subscription (e.g. dev/test/prod UMAIs) than the tools sub that hosts
    # the Bastion. Without it, az CLI resolves --resource-group in the active
    # subscription context and fails with ResourceGroupNotFound.
    az network bastion ssh \
      --name "$bastion_name" \
      --resource-group "$bastion_rg" \
      --subscription "$bastion_sub" \
      --target-resource-id "$JUMPBOX_RESOURCE_ID" \
      --auth-type "AAD" \
      -- -D "$SOCKS_PORT" -N \
         -o StrictHostKeyChecking=no \
         -o UserKnownHostsFile=/dev/null \
      >"${PID_DIR}/ssh-socks-proxy.log" 2>&1 &
    echo $! > "$PROXY_PID_FILE"

    # Wait for the SOCKS5 port to be ready.
    for _ in $(seq 1 30); do
      (exec 3<>"/dev/tcp/127.0.0.1/${SOCKS_PORT}") 2>/dev/null && exec 3>&- && break
      sleep 1
    done

    # Start the HTTP CONNECT → SOCKS5h bridge.
    #
    # Go's net/http (used by Terraform's Azure backend) understands http:// and
    # socks5:// proxy schemes but NOT socks5h://. With HTTPS_PROXY=socks5h://...
    # Go tries to DNS-resolve "socks5h" as a hostname and fails. We need remote
    # DNS (socks5h behaviour) because the Azure Storage private endpoint only
    # resolves to a private IP from within the Azure VNet — the GitHub runner
    # can't resolve it locally. The bridge accepts HTTP CONNECT (which Go CAN
    # use) and forwards each connection into the SOCKS5 proxy using ATYP=0x03
    # (domain name), so the jumpbox performs DNS resolution inside the VNet.
    python3 "${SCRIPT_DIR}/socks5h-bridge.py" "$BRIDGE_PORT" 127.0.0.1 "$SOCKS_PORT" \
      >"${PID_DIR}/socks5h-bridge.log" 2>&1 &
    echo $! > "$BRIDGE_PID_FILE"
    sleep 1  # let bridge bind

    # Quick sanity check: verify the full proxy chain is functional before we
    # set HTTPS_PROXY and let Terraform run. Tests two layers:
    #   1. SSH SOCKS5 proxy directly (bypasses the bridge)
    #   2. HTTP CONNECT bridge (the path Terraform uses)
    # api.ipify.org is a public service that returns the caller's outbound IP —
    # through the tunnel this should be the jumpbox's IP, proving end-to-end
    # routing. It is NOT in NO_PROXY so it always routes through the proxy.
    echo "--- ssh socks proxy log ---"
    cat "${PID_DIR}/ssh-socks-proxy.log" 2>/dev/null || true
    echo "--- bridge log ---"
    cat "${PID_DIR}/socks5h-bridge.log" 2>/dev/null || true
    echo "--- proxy chain test (layer 1: SSH SOCKS5 direct) ---"
    curl -v --socks5-hostname "127.0.0.1:${SOCKS_PORT}" \
      --connect-timeout 15 --max-time 20 \
      "https://api.ipify.org?format=text" \
      2>&1 && echo "" || echo "socks5 direct test failed (exit $?)"
    echo "--- proxy chain test (layer 2: HTTP CONNECT bridge) ---"
    curl -v --proxy "http://127.0.0.1:${BRIDGE_PORT}" \
      --connect-timeout 15 --max-time 20 \
      "https://api.ipify.org?format=text" \
      2>&1 && echo "" || echo "bridge test failed (exit $?)"
    echo "--- end proxy chain test ---"

    {
      # ALL_PROXY (socks5h): for tools that natively support the socks5h scheme
      # (curl, az CLI) so they also get remote DNS resolution.
      echo "ALL_PROXY=socks5h://127.0.0.1:${SOCKS_PORT}"
      # HTTPS_PROXY / HTTP_PROXY: set to the HTTP CONNECT bridge so that Go-based
      # tools (Terraform, azurerm provider) use a scheme they understand. The
      # bridge internally forwards using SOCKS5 with remote DNS (ATYP=0x03),
      # giving the same socks5h behaviour without requiring Go to parse socks5h://.
      echo "HTTPS_PROXY=http://127.0.0.1:${BRIDGE_PORT}"
      echo "HTTP_PROXY=http://127.0.0.1:${BRIDGE_PORT}"
      # Bypass the proxy entirely for public endpoints that must be reached directly:
      # - GitHub OIDC token endpoint (ARM_USE_OIDC=true fetches a JWT from here)
      # - Azure AAD token endpoint (azure/login OIDC exchange)
      # - Azure management plane (ARM API calls; public, no private endpoint)
      # These are all reachable from the runner without a tunnel. Routing them
      # through the bridge is harmless but adds latency and complexity.
      echo "NO_PROXY=localhost,127.0.0.1,*.actions.githubusercontent.com,token.actions.githubusercontent.com,login.microsoftonline.com,management.azure.com"
    } >> "$GITHUB_ENV"
    ;;

  stop)
    echo "--- ssh socks proxy log (full session) ---"
    cat "${PID_DIR}/ssh-socks-proxy.log" 2>/dev/null || true
    echo "--- bridge log (full session) ---"
    cat "${PID_DIR}/socks5h-bridge.log" 2>/dev/null || true
    echo "--- end logs ---"
    [ -f "$BRIDGE_PID_FILE" ] && kill "$(cat "$BRIDGE_PID_FILE")" 2>/dev/null || true
    [ -f "$PROXY_PID_FILE" ]  && kill "$(cat "$PROXY_PID_FILE")"  2>/dev/null || true
    rm -f "$BRIDGE_PID_FILE" "$PROXY_PID_FILE"
    # Clear proxy vars so post-job steps (azure/login cleanup, actions/checkout)
    # don't fail trying to reach public endpoints through a now-dead tunnel.
    if [ -n "${GITHUB_ENV:-}" ]; then
      printf 'ALL_PROXY=\nHTTPS_PROXY=\nHTTP_PROXY=\nNO_PROXY=\n' >> "$GITHUB_ENV"
    fi
    ;;

  *)
    echo "usage: bastion-proxy.sh start|stop" >&2
    exit 1
    ;;
esac
