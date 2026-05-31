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

# Render the rsyncd secrets file that rsync daemon uses for auth
template {
  source      = "/opt/vault-agent/templates/rsyncd-secrets.tpl"
  destination = "/etc/rsyncd.secrets"
  perms       = "0600"
}

# Render the S3 credentials/env file used by the AD backup job
template {
  source      = "/opt/vault-agent/templates/samba-ad-backup.env.tpl"
  destination = "/etc/default/samba-ad-backup"
  perms       = "0600"
}
