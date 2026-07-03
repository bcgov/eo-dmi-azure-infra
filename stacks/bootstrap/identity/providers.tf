terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

# Default (unaliased) provider - used for everything homed in b9cee3-tools:
# the identity resource group, the 4 UAMIs, the tools subscription role
# assignments, and the Bastion/jumpbox role assignments.
provider "azurerm" {
  features {}
  subscription_id = var.subscription_ids.tools
}

provider "azurerm" {
  features {}
  alias           = "dev"
  subscription_id = var.subscription_ids.dev
}

provider "azurerm" {
  features {}
  alias           = "test"
  subscription_id = var.subscription_ids.test
}

provider "azurerm" {
  features {}
  alias           = "prod"
  subscription_id = var.subscription_ids.prod
}
