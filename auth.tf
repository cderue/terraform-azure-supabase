# Container App - Auth Service
resource "azurerm_container_app" "auth" {
  name                         = "supabase-auth"
  container_app_environment_id = azurerm_container_app_environment.env.id
  resource_group_name          = azurerm_resource_group.rg.name
  revision_mode                = "Single"

  template {
    container {
      name   = "auth"
      image  = "supabase/gotrue:v2.170.0"
      cpu    = 0.5
      memory = "1Gi"

      env {
        name  = "GOTRUE_API_HOST"
        value = "0.0.0.0"
      }
      env {
        name  = "GOTRUE_API_PORT"
        value = "9999"
      }
      env {
        name  = "API_EXTERNAL_URL"
        value = "https://${azurerm_container_app.kong.ingress[0].fqdn}"
      }
      env {
        name  = "GOTRUE_DB_DRIVER"
        value = "postgres"
      }
      env {
        name  = "GOTRUE_DB_DATABASE_URL"
        value = "postgres://supabase_auth_admin:${random_password.postgres_password.result}@${azurerm_container_app.db.ingress[0].fqdn}:5432/postgres"
      }
      env {
        name  = "GOTRUE_SITE_URL"
        value = "https://${azurerm_container_app.kong.ingress[0].fqdn}"
      }
      env {
        name  = "GOTRUE_JWT_SECRET"
        value = random_password.jwt_secret.result
      }
      env {
        name  = "GOTRUE_JWT_EXP"
        value = "3600"
      }
      env {
        name  = "GOTRUE_JWT_DEFAULT_GROUP_NAME"
        value = "authenticated"
      }
    }
  }

  ingress {
    allow_insecure_connections = false
    external_enabled           = false
    target_port                = 9999
    transport                  = "http"
  }

  registry {
    server   = "docker.io"
    identity = "System"
  }

  depends_on = [azurerm_container_app.db, azurerm_container_app.analytics]
}
