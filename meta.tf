# Container App - Metadata Service
resource "azurerm_container_app" "meta" {
  name                         = "supabase-meta"
  container_app_environment_id = azurerm_container_app_environment.env.id
  resource_group_name          = azurerm_resource_group.rg.name
  revision_mode                = "Single"

  template {
    container {
      name   = "meta"
      image  = "supabase/postgres-meta:v0.87.1"
      cpu    = 0.5
      memory = "1Gi"

      env {
        name  = "PG_META_PORT"
        value = "8080"
      }
      env {
        name  = "PG_META_DB_HOST"
        value = azurerm_container_app.db.ingress[0].fqdn
      }
      env {
        name  = "PG_META_DB_PORT"
        value = "5432"
      }
      env {
        name  = "PG_META_DB_NAME"
        value = "postgres"
      }
      env {
        name  = "PG_META_DB_USER"
        value = "supabase_admin"
      }
      env {
        name  = "PG_META_DB_PASSWORD"
        value = random_password.postgres_password.result
      }
    }
  }

  ingress {
    allow_insecure_connections = false
    external_enabled           = false
    target_port                = 8080
    transport                  = "http"
  }

  registry {
    server   = "docker.io"
    identity = "System"
  }

  depends_on = [azurerm_container_app.db, azurerm_container_app.analytics]
}
