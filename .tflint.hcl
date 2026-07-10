config {
  # Don't try to resolve local module calls. Module resolution requires
  # provider schemas to be installed (`terraform init` with real credentials),
  # which CI can't do at lint time. Module syntax and variable types are
  # already checked by `terraform validate` in the same workflow.
  call_module_type = "none"
}

plugin "azurerm" {
  enabled = true
  version = "0.27.0"
  source  = "github.com/terraform-linters/tflint-ruleset-azurerm"
}

# Modules intentionally omit required_version / required_providers — callers
# (stacks) own those constraints and modules inherit them. Disabling these two
# rules avoids 14 spurious warnings on every CI run.
rule "terraform_required_version" {
  enabled = false
}

rule "terraform_required_providers" {
  enabled = false
}
