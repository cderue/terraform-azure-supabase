# Container App - Kong API Gateway
resource "azurerm_container_app" "kong" {
  name                         = "supabase-kong"
  container_app_environment_id = azurerm_container_app_environment.env.id
  resource_group_name          = azurerm_resource_group.rg.name
  revision_mode                = "Single"

  template {
    container {
      name   = "kong"
      image  = "kong:2.8.1"
      cpu    = 0.5
      memory = "1Gi"
      
      # This setup requires you to provide the kong.yml configuration
      # This is a placeholder implementation
      env {
        name  = "KONG_DATABASE"
        value = "off"
      }
      env {
        name  = "KONG_DECLARATIVE_CONFIG"
        value = "/home/kong/kong.yml"
      }
      env {
        name  = "KONG_DNS_ORDER"
        value = "LAST,A,CNAME"
      }
      env {
        name  = "KONG_PLUGINS"
        value = "request-transformer,cors,key-auth,acl,basic-auth"
      }
      env {
        name  = "KONG_NGINX_PROXY_PROXY_BUFFER_SIZE"
        value = "160k"
      }
      env {
        name  = "KONG_NGINX_PROXY_PROXY_BUFFERS"
        value = "64 160k"
      }
      env {
        name  = "SUPABASE_ANON_KEY"
        value = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24ifQ.625_WdcF3KHqz5amU0x2X5WWHP-OEs_4qj0ssLNHzTs"
      }
      env {
        name  = "SUPABASE_SERVICE_KEY"
        value = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6InNlcnZpY2Vfcm9sZSJ9.vI9obAHOGyVVKa3pD--kJlyxp-Z2zV9UUMAhKpNLAcU"
      }
      env {
        name  = "DASHBOARD_USERNAME"
        value = "admin"
      }
      env {
        name  = "DASHBOARD_PASSWORD"
        value = "admin_password"
      }
      
      # This requires a custom initialization script to properly configure Kong
      # For a complete implementation, use a custom container image with kong.yml
    }
  }

  ingress {
    allow_insecure_connections = false
    external_enabled           = true
    target_port                = 8000
    transport                  = "http"
  }

  registry {
    server   = "docker.io"
    identity = "System"
  }

  depends_on = [
    azurerm_container_app.analytics,
    azurerm_container_app.rest,
    azurerm_container_app.auth,
    azurerm_container_app.storage,
    azurerm_container_app.realtime
  ]
}
