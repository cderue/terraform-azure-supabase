# Container App - Image Proxy Service
resource "azurerm_container_app" "imgproxy" {
  name                         = "supabase-imgproxy"
  container_app_environment_id = azurerm_container_app_environment.env.id
  resource_group_name          = azurerm_resource_group.rg.name
  revision_mode                = "Single"

  template {
    container {
      name   = "imgproxy"
      image  = "darthsim/imgproxy:v3.8.0"
      cpu    = 0.5
      memory = "1Gi"

      env {
        name  = "IMGPROXY_BIND"
        value = ":5001"
      }
      env {
        name  = "IMGPROXY_LOCAL_FILESYSTEM_ROOT"
        value = "/"
      }
      env {
        name  = "IMGPROXY_USE_ETAG"
        value = "true"
      }
      env {
        name  = "IMGPROXY_ENABLE_WEBP_DETECTION"
        value = "true"
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
    target_port                = 5001
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

  depends_on = [azurerm_container_app.db]
}
