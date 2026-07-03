output "shared_capacity_ids" {
  description = "Resource IDs of shared Fabric capacities homed in this environment, keyed by capacity name (from params/global/fabric-capacities.yaml)."
  value = {
    for name, mod in module.fabric_capacity : name => mod.id
  }
}
