# Container App - Storage Service
resource "azurerm_container_app" "storage" {
  name                         = "supabase-storage"
  container_app_environment_id = azurerm_container_app_environment.env.id
  resource_group_name          = azurerm_resource_group.rg.name
  revision_mode                = "Single"

  template {
    container {
      name   = "storage"
      image  = "supabase/storage-api:v1.19.3"
      cpu    = 0.5
      memory = "1Gi"

      env {
        name  = "ANON_KEY"
        value = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24ifQ.625_WdcF3KHqz5amU0x2X5WWHP-OEs_4qj0ssLNHzTs"
      }
      env {
        name  = "SERVICE_KEY"
        value = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6InNlcnZpY2Vfcm9sZSJ9.vI9obAHOGyVVKa3pD--kJlyxp-Z2zV9UUMAhKpNLAcU"
      }
      env {
        name  = "POSTGREST_URL"
        value = "http://${azurerm_container_app.rest.ingress[0].fqdn}:3000"
      }
      env {
        name  = "PGRST_JWT_SECRET"
        value = random_password.jwt_secret.result
      }
      env {
        name  = "DATABASE_URL"
        value = "postgres://supabase_storage_admin:${random_password.postgres_password.result}@${azurerm_container_app.db.ingress[0].fqdn}:5432/postgres"
      }
      env {
        name  = "FILE_SIZE_LIMIT"
        value = "52428800"
      }
      env {
        name  = "STORAGE_BACKEND"
        value = "file"
      }
      env {
        name  = "FILE_STORAGE_BACKEND_PATH"
        value = "/var/lib/storage"
      }
      env {
        name  = "TENANT_ID"
        value = "stub"
      }
      env {
        name  = "REGION"
        value = "stub"
      }
      env {
        name  = "GLOBAL_S3_BUCKET"
        value = "stub"
      }
      env {
        name  = "ENABLE_IMAGE_TRANSFORMATION"
        value = "true"
      }
      env {
        name  = "IMGPROXY_URL"
        value = "http://${azurerm_container_app.imgproxy.ingress[0].fqdn}:5001"
      }

      volume_mounts {
        name = "storage-data"
        path = "/var/lib/storage"
      }
    }

    volume {
      name         = "storage-data"
      storage_type = "AzureFile"
      storage_name = "storage-data"
    }
  }

  ingress {
    allow_insecure_connections = false
    external_enabled           = false
    target_port                = 5000
    transport                  = "http"
  }

  registry {
    server   = "docker.io"
    identity = "System"
  }

  storage {
    name         = "storage-data"
    account_name = azurerm_storage_account.storage.name
    share_name   = azurerm_storage_share.storage_data.name
    access_key   = azurerm_storage_account.storage.primary_access_key
  }

  depends_on = [azurerm_container_app.rest, azurerm_container_app.imgproxy]
}
