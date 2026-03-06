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
  source      = "/vault-agent/templates/technitium.tpl"
  destination = "/secrets/technitium/technitium.env"
}

template {
  source      = "/vault-agent/templates/tailscale.tpl"
  destination = "/secrets/tailscale/tailscale.env"
}

template {
  source      = "/vault-agent/templates/omada.tpl"
  destination = "/secrets/omada/omada.env"
}

template {
  source      = "/vault-agent/templates/gatus.tpl"
  destination = "/secrets/gatus/gatus.env"
}

template {
  source      = "/vault-agent/templates/ntfy.tpl"
  destination = "/secrets/ntfy/ntfy.env"
}

template {
  source      = "/vault-agent/templates/github-runner.tpl"
  destination = "/secrets/github-runner/github-runner.env"
}
