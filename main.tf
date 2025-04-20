# Resource Group
resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.location
}

# Storage Account for persistent data
resource "azurerm_storage_account" "storage" {
  name                     = "supabasestorage${random_id.storage_account_name.hex}"
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "random_id" "storage_account_name" {
  byte_length = 8
}

# Log Analytics Workspace for Container Apps
resource "azurerm_log_analytics_workspace" "workspace" {
  name                = "supabase-logs"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
}

# Container Apps Environment
resource "azurerm_container_app_environment" "env" {
  name                       = "supabase-env"
  location                   = azurerm_resource_group.rg.location
  resource_group_name        = azurerm_resource_group.rg.name
  log_analytics_workspace_id = azurerm_log_analytics_workspace.workspace.id
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

  depends_on = [azurerm_container_app.db]
}



  ingress {
    allow_insecure_connections = false
    external_enabled           = false
    target_port                = 3000
    transport                  = "http"
  }

  registry {
    server   = "docker.io"
    identity = "System"
  }

  depends_on = [azurerm_container_app.db, azurerm_container_app.analytics]
}






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
