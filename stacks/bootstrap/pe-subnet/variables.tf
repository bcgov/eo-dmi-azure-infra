variable "subscription_id" {
  description = "Subscription ID for the target environment."
  type        = string
}

variable "vnet_resource_group" {
  description = "Resource group containing the existing platform spoke VNet."
  type        = string
}

variable "vnet_name" {
  description = "Name of the existing platform spoke VNet."
  type        = string
}

variable "subnet_name" {
  description = "Name for the new PE subnet."
  type        = string
  default     = "privateendpoints-subnet"
}

variable "address_prefix" {
  description = "CIDR block for the new PE subnet. Must fall within the VNet's address space. Use a /27 to match the existing tools/dev convention."
  type        = string
}
