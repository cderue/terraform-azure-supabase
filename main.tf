# Resource Group
resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.location
}

# Storage Account for persistent data
resource "azurerm_storage_account" "storage" {
  name                     = "supabasestorage${random_id.storage_account_name.hex}"
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "random_id" "storage_account_name" {
  byte_length = 8
}

# Log Analytics Workspace for Container Apps
resource "azurerm_log_analytics_workspace" "workspace" {
  name                = "supabase-logs"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
}

# Container Apps Environment
resource "azurerm_container_app_environment" "env" {
  name                       = "supabase-env"
  location                   = azurerm_resource_group.rg.location
  resource_group_name        = azurerm_resource_group.rg.name
  log_analytics_workspace_id = azurerm_log_analytics_workspace.workspace.id
}





  



  ingress {
    allow_insecure_connections = false
    external_enabled           = false
    target_port                = 3000
    transport                  = "http"
  }

  registry {
    server   = "docker.io"
    identity = "System"
  }

  depends_on = [azurerm_container_app.db, azurerm_container_app.analytics]
}
