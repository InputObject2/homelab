vault {
  address = "VAULT_ADDR_PLACEHOLDER"  # overridden by VAULT_ADDR env var in systemd unit
}

auto_auth {
  method "approle" {
    config = {
      role_id_file_path             = "/opt/vault-agent/role-id"
      secret_id_file_path           = "/opt/vault-agent/secret-id"
      remove_secret_id_file_after_reading = false
    }
  }

  sink "file" {
    config = {
      path = "/opt/vault-agent/token"
    }
  }
}

# Render the rsync client password file used by the sysvol-rsync cron
template {
  source      = "/opt/vault-agent/templates/rsyncd-client-secret.tpl"
  destination = "/etc/rsyncd.client.secret"
  perms       = "0600"
}
