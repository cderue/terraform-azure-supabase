resource "azurerm_container_app" "studio" {
  name                         = "supabase-studio"
  container_app_environment_id = azurerm_container_app_environment.env.id
  resource_group_name          = azurerm_resource_group.rg.name
  revision_mode                = "Single"
  
  template {
    container {
      name    = "studio"
      image   = "supabase/studio:20250317-6955350"
      cpu     = 0.5
      memory  = "1Gi"
      
      env {
        name  = "STUDIO_PG_META_URL"
        value = "http://${azurerm_container_app.meta.ingress[0].fqdn}:8080"
      }
      
      env {
        name  = "POSTGRES_PASSWORD"
        value = random_password.postgres_password.result
      }
      
      env {
        name  = "DEFAULT_ORGANIZATION_NAME"
        value = "My Organization"
      }
      
      env {
        name  = "DEFAULT_PROJECT_NAME"
        value = "Default Project"
      }
      
      env {
        name  = "SUPABASE_URL"
        value = "http://${azurerm_container_app.kong.ingress[0].fqdn}:8000"
      }
      
      env {
        name  = "SUPABASE_PUBLIC_URL"
        value = "https://${azurerm_container_app.kong.ingress[0].fqdn}"
      }
      
      env {
        name  = "SUPABASE_ANON_KEY"
        value = var.supabase_anon_key
      }
      
      env {
        name  = "SUPABASE_SERVICE_KEY"
        value = var.supabase_service_key
      }
    }
  }
  
  ingress {
    external_enabled = true
    target_port      = 3000
    traffic_weight {
      latest_revision = true
      percentage      = 100
    }
  }

  identity {
    type = "SystemAssigned"
  }

  tags = {
    environment = var.environment
    application = "supabase-studio"
  }
}
