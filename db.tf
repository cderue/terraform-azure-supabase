# Container App - Database
resource "azurerm_container_app" "db" {
  name                         = "supabase-db"
  container_app_environment_id = azurerm_container_app_environment.env.id
  resource_group_name          = azurerm_resource_group.rg.name
  revision_mode                = "Single"

  template {
    container {
      name   = "postgres"
      image  = "supabase/postgres:15.8.1.060"
      cpu    = 1.0
      memory = "2Gi"

      env {
        name  = "POSTGRES_PASSWORD"
        value = random_password.postgres_password.result
      }
      env {
        name  = "POSTGRES_PORT"
        value = "5432"
      }
      env {
        name  = "POSTGRES_DB"
        value = "postgres"
      }
      env {
        name  = "JWT_SECRET"
        value = random_password.jwt_secret.result
      }
      env {
        name  = "JWT_EXP"
        value = "3600"
      }

      volume_mounts {
        name = "pgdata"
        path = "/var/lib/postgresql/data"
      }
    }

    volume {
      name         = "pgdata"
      storage_type = "AzureFile"
      storage_name = "pgdata"
    }
  }

  ingress {
    allow_insecure_connections = false
    external_enabled           = false
    target_port                = 5432
    transport                  = "tcp"
  }

  registry {
    server   = "docker.io"
    identity = "System"
  }

  secret {
    name  = "storage-connection-string"
    value = azurerm_storage_account.storage.primary_connection_string
  }

  storage {
    name         = "pgdata"
    account_name = azurerm_storage_account.storage.name
    share_name   = azurerm_storage_share.pgdata.name
    access_key   = azurerm_storage_account.storage.primary_access_key
  }
}

# File share
resource "azurerm_storage_share" "pgdata" {
  name                 = "pgdata"
  storage_account_name = azurerm_storage_account.storage.name
  quota                = 50
}
