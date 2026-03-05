vault {
  address = "VAULT_ADDR_PLACEHOLDER"  # overridden by VAULT_ADDR env var
}

auto_auth {
  method "approle" {
    config = {
      role_id_file_path   = "/vault-agent/role-id"
      secret_id_file_path = "/vault-agent/secret-id"
    }
  }

  sink "file" {
    config = {
      path = "/vault-agent/token"
    }
  }
}

template {
  source      = "/vault-agent/templates/observability.tpl"
  destination = "/secrets/observability/observability.env"
}
