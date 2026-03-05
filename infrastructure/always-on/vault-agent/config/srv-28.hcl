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
  source      = "/vault-agent/templates/homeassistant.tpl"
  destination = "/secrets/homeassistant/homeassistant.env"
}

template {
  source      = "/vault-agent/templates/matterbridge.tpl"
  destination = "/secrets/matterbridge/matterbridge.env"
}

template {
  source      = "/vault-agent/templates/voip.tpl"
  destination = "/secrets/voip/voip.env"
}
