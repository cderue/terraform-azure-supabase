# Generate random values for secrets
resource "random_password" "postgres_password" {
  length  = 32
  special = true
}

resource "random_password" "jwt_secret" {
  length  = 32
  special = true
}

resource "random_id" "logflare_api_key" {
  byte_length = 16
}

resource "random_password" "secret_key_base" {
  length  = 64
  special = true
}

resource "random_password" "vault_enc_key" {
  length  = 32
  special = true
}
