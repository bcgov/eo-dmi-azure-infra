resource "azurerm_private_endpoint" "this" {
  name                = var.name
  resource_group_name = var.resource_group_name
  location            = var.location
  subnet_id           = var.subnet_id

  private_service_connection {
    name                           = "${var.name}-psc"
    private_connection_resource_id = var.target_resource_id
    subresource_names              = var.subresource_names
    is_manual_connection           = false
  }

  dynamic "private_dns_zone_group" {
    for_each = length(var.private_dns_zone_ids) > 0 ? [1] : []

    content {
      name                 = "default"
      private_dns_zone_ids = var.private_dns_zone_ids
    }
  }

  tags = merge(var.tags, { "managed-by" = "terraform" })

  lifecycle {
    # The ALZ DINE policy creates a "deployedByPolicy" private_dns_zone_group on
    # every private endpoint, registering it into the central
    # privatelink.vaultcore.azure.net zone in the bcgov-managed-lz-live-dns
    # subscription. Terraform does not own that block: with private_dns_zone_ids
    # empty (the documented default - see params/global/network-reference.yaml)
    # the dynamic block above produces nothing, so without this Terraform plans to
    # DELETE the policy's zone group. That would break name resolution for the
    # Key Vault private endpoint - the vault would stop resolving to its private
    # IP and become unreachable even through the Bastion tunnel.
    #
    # Consequence: Terraform no longer reconciles this block at all, so setting
    # private_dns_zone_ids on an existing endpoint has no effect. That is
    # acceptable here because the central zone lives in another subscription and
    # tenant UAMIs lack privateDnsZones/join on it, so self-managed zone groups
    # were never actually possible. Revisit if DNS registration ever moves
    # in-repo.
    ignore_changes = [private_dns_zone_group]
  }
}
