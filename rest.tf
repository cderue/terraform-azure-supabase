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
