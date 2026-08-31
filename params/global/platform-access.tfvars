# Principals granted Virtual Machine User Login on the shared Bastion jumpbox.
# Add any user or Entra group that needs to open a Bastion tunnel to reach
# tenant private endpoints (Key Vaults, storage, Fabric).
#
# Use object IDs (not UPNs) — UPNs change when users are renamed.
# To find an object ID: az ad user show --id email@gov.bc.ca --query id -o tsv
#
# Each principal gets Virtual Machine User Login on the jumpbox VM, and Reader on
# the Bastion's RESOURCE GROUP - not the Bastion host, which is deleted nightly to
# avoid charges. See stacks/platform-access/main.tf.
#
# Changes here trigger an automatic re-apply of stacks/platform-access via CI.
jumpbox_principal_ids = [
  "c2c84491-e623-4f89-b6be-7e36bff00374", # jakia
  "8ec30563-1186-4a45-94d4-a7f8403924e7", # wei
  "acc400f6-00af-4401-8720-9fa3770b1845", # krishna
  "8a0af36a-54cd-4432-8a5e-3a2b55209eae", # sree (bcts)
]

