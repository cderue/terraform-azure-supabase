# Container App - Functions Service
resource "azurerm_container_app" "functions" {
  name                         = "supabase-functions"
  container_app_environment_id = azurerm_container_app_environment.env.id
  resource_group_name          = azurerm_resource_group.rg.name
  revision_mode                = "Single"

  template {
    container {
      name   = "functions"
      image  = "supabase/edge-runtime:v1.67.4"
      cpu    = 0.5
      memory = "1Gi"
      command = [
        "start",
        "--main-service",
        "/home/deno/functions/main"
      ]

      env {
        name  = "JWT_SECRET"
        value = random_password.jwt_secret.result
      }
      env {
        name  = "SUPABASE_URL"
        value = "http://${azurerm_container_app.kong.ingress[0].fqdn}:8000"
      }
      env {
        name  = "SUPABASE_ANON_KEY"
        value = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24ifQ.625_WdcF3KHqz5amU0x2X5WWHP-OEs_4qj0ssLNHzTs"
      }
      env {
        name  = "SUPABASE_SERVICE_ROLE_KEY"
        value = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6InNlcnZpY2Vfcm9sZSJ9.vI9obAHOGyVVKa3pD--kJlyxp-Z2zV9UUMAhKpNLAcU"
      }
      env {
        name  = "SUPABASE_DB_URL"
        value = "postgresql://postgres:${random_password.postgres_password.result}@${azurerm_container_app.db.ingress[0].fqdn}:5432/postgres"
      }
      env {
        name  = "VERIFY_JWT"
        value = "true"
      }

      volume_mounts {
        name = "functions-data"
        path = "/home/deno/functions"
      }
    }

    volume {
      name         = "functions-data"
      storage_type = "EmptyDir"
    }
  }

  ingress {
    allow_insecure_connections = false
    external_enabled           = false
    target_port                = 9000
    transport                  = "http"
  }

  registry {
    server   = "docker.io"
    identity = "System"
  }

  depends_on = [azurerm_container_app.analytics]
}
