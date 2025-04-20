# Resource Group
resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.location
}

# Storage Account for persistant data
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

# File Shares
resource "azurerm_storage_share" "pgdata" {
  name                 = "pgdata"
  storage_account_name = azurerm_storage_account.storage.name
  quota                = 50
}

resource "azurerm_storage_share" "storage_data" {
  name                 = "storage"
  storage_account_name = azurerm_storage_account.storage.name
  quota                = 50
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

# Container App - REST API
resource "azurerm_container_app" "rest" {
  name                         = "supabase-rest"
  container_app_environment_id = azurerm_container_app_environment.env.id
  resource_group_name          = azurerm_resource_group.rg.name
  revision_mode                = "Single"

  template {
    container {
      name   = "rest"
      image  = "postgrest/postgrest:v12.2.8"
      cpu    = 0.5
      memory = "1Gi"

      env {
        name  = "PGRST_DB_URI"
        value = "postgres://authenticator:${random_password.postgres_password.result}@${azurerm_container_app.db.ingress[0].fqdn}:5432/postgres"
      }
      env {
        name  = "PGRST_DB_SCHEMAS"
        value = "public,storage,graphql_public"
      }
      env {
        name  = "PGRST_DB_ANON_ROLE"
        value = "anon"
      }
      env {
        name  = "PGRST_JWT_SECRET"
        value = random_password.jwt_secret.result
      }
      env {
        name  = "PGRST_DB_USE_LEGACY_GUCS"
        value = "false"
      }
      env {
        name  = "PGRST_APP_SETTINGS_JWT_SECRET"
        value = random_password.jwt_secret.result
      }
      env {
        name  = "PGRST_APP_SETTINGS_JWT_EXP"
        value = "3600"
      }
    }
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
