locals {
  # try(...) falls back to {} when params/global/fabric-capacities.yaml has
  # no active "capacities:" key (e.g. capacities intentionally disabled for
  # now) - yamldecode of an all-comment/empty document returns null, and
  # null.capacities would otherwise error.
  capacity_registry = try(yamldecode(file("${path.module}/../../params/global/fabric-capacities.yaml")).capacities, {})

  # Only capacities with scope "shared-cross-env" or "shared-env" that are
  # homed in this environment get created here. "dedicated" capacities are
  # created by stacks/tenant instead.
  shared_capacities = {
    for name, cap in local.capacity_registry : name => cap
    if cap.home_env == var.environment && cap.scope != "dedicated"
  }
}
