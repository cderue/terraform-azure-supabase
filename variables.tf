# Define variables
variable "location" {
  description = "Azure region to deploy resources"
  default     = "eastus"
}

variable "resource_group_name" {
  description = "Resource group name"
  default     = "supabase-rg"
}
