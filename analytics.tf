# Container App - Analytics
resource "azurerm_container_app" "analytics" {
  name                         = "supabase-analytics"
  container_app_environment_id = azurerm_container_app_environment.env.id
  resource_group_name          = azurerm_resource_group.rg.name
  revision_mode                = "Single"

  template {
    container {
      name   = "analytics"
      image  = "supabase/logflare:1.12.0"
      cpu    = 0.5
      memory = "1Gi"

      env {
        name  = "LOGFLARE_NODE_HOST"
        value = "127.0.0.1"
      }
      env {
        name  = "DB_USERNAME"
        value = "supabase_admin"
      }
      env {
        name  = "DB_DATABASE"
        value = "_supabase"
      }
      env {
        name  = "DB_HOSTNAME"
        value = azurerm_container_app.db.ingress[0].fqdn
      }
      env {
        name  = "DB_PORT"
        value = "5432"
      }
      env {
        name  = "DB_PASSWORD"
        value = random_password.postgres_password.result
      }
      env {
        name  = "DB_SCHEMA"
        value = "_analytics"
      }
      env {
        name  = "LOGFLARE_API_KEY"
        value = random_id.logflare_api_key.hex
      }
      env {
        name  = "LOGFLARE_SINGLE_TENANT"
        value = "true"
      }
      env {
        name  = "LOGFLARE_SUPABASE_MODE"
        value = "true"
      }
      env {
        name  = "LOGFLARE_MIN_CLUSTER_SIZE"
        value = "1"
      }
      env {
        name  = "POSTGRES_BACKEND_URL"
        value = "postgresql://supabase_admin:${random_password.postgres_password.result}@${azurerm_container_app.db.ingress[0].fqdn}:5432/_supabase"
      }
      env {
        name  = "POSTGRES_BACKEND_SCHEMA"
        value = "_analytics"
      }
      env {
        name  = "LOGFLARE_FEATURE_FLAG_OVERRIDE"
        value = "multibackend=true"
      }
    }
  }
