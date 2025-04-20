# Container App - Realtime Service
resource "azurerm_container_app" "realtime" {
  name                         = "supabase-realtime"
  container_app_environment_id = azurerm_container_app_environment.env.id
  resource_group_name          = azurerm_resource_group.rg.name
  revision_mode                = "Single"

  template {
    container {
      name   = "realtime"
      image  = "supabase/realtime:v2.34.43"
      cpu    = 0.5
      memory = "1Gi"

      env {
        name  = "PORT"
        value = "4000"
      }
      env {
        name  = "DB_HOST"
        value = azurerm_container_app.db.ingress[0].fqdn
      }
      env {
        name  = "DB_PORT"
        value = "5432"
      }
      env {
        name  = "DB_USER"
        value = "supabase_admin"
      }
      env {
        name  = "DB_PASSWORD"
        value = random_password.postgres_password.result
      }
      env {
        name  = "DB_NAME"
        value = "postgres"
      }
      env {
        name  = "DB_AFTER_CONNECT_QUERY"
        value = "SET search_path TO _realtime"
      }
      env {
        name  = "DB_ENC_KEY"
        value = "supabaserealtime"
      }
      env {
        name  = "API_JWT_SECRET"
        value = random_password.jwt_secret.result
      }
      env {
        name  = "SECRET_KEY_BASE"
        value = random_password.secret_key_base.result
      }
      env {
        name  = "ERL_AFLAGS"
        value = "-proto_dist inet_tcp"
      }
      env {
        name  = "DNS_NODES"
        value = "''"
      }
      env {
        name  = "RLIMIT_NOFILE"
        value = "10000"
      }
      env {
        name  = "APP_NAME"
        value = "realtime"
      }
      env {
        name  = "SEED_SELF_HOST"
        value = "true"
      }
      env {
        name  = "RUN_JANITOR"
        value = "true"
      }
    }
  }

  ingress {
    allow_insecure_connections = false
    external_enabled           = false
    target_port                = 4000
    transport                  = "http"
  }

  registry {
    server   = "docker.io"
    identity = "System"
  }

  depends_on = [azurerm_container_app.db, azurerm_container_app.analytics]
}
