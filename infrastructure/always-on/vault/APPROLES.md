# AppRole Setup Guide

This document describes how to manually recreate the AppRole auth method and roles in HashiCorp Vault for the always-on infrastructure machines.

## Prerequisites

- Vault CLI installed and authenticated with admin token
- `vault_addr` environment variable set to your Vault server URL

## Setup Steps

### 1. Enable AppRole Auth Method

```bash
vault auth enable approle
```

### 2. Create Policies

Upload the policy files to Vault:

```bash
vault policy write shared infrastructure/always-on/vault/policies/shared.hcl
vault policy write srv-26 infrastructure/always-on/vault/policies/srv-26.hcl
vault policy write srv-27 infrastructure/always-on/vault/policies/srv-27.hcl
vault policy write srv-28 infrastructure/always-on/vault/policies/srv-28.hcl
```

### 3. Create AppRoles for Each Machine

#### For srv-26:
```bash
vault write auth/approle/role/srv-26 \
  token_ttl=1h \
  token_max_ttl=4h \
  policies="shared,srv-26"

# Fetch role-id
vault read auth/approle/role/srv-26/role-id

# Generate secret-id (never commit this, pass directly to the machine)
vault write -f auth/approle/role/srv-26/secret-id
```

#### For srv-27:
```bash
vault write auth/approle/role/srv-27 \
  token_ttl=1h \
  token_max_ttl=4h \
  policies="shared,srv-27"

# Fetch role-id
vault read auth/approle/role/srv-27/role-id

# Generate secret-id
vault write -f auth/approle/role/srv-27/secret-id
```

#### For srv-28:
```bash
vault write auth/approle/role/srv-28 \
  token_ttl=1h \
  token_max_ttl=4h \
  policies="shared,srv-28"

# Fetch role-id
vault read auth/approle/role/srv-28/role-id

# Generate secret-id
vault write -f auth/approle/role/srv-28/secret-id
```

### 4. Write Secrets to Vault

Create secrets at the paths referenced in vault-agent templates:

```bash
# srv-26 secrets
vault kv put secrets/infra/srv-26/technitium \
  password="your-technitium-admin-password"

vault kv put secrets/infra/srv-26/tailscale \
  authkey="tskey-xxxxxxxxxxxxx"

vault kv put secrets/infra/srv-26/omada \
  admin_password="your-omada-password"

vault kv put secrets/infra/srv-26/gatus \
  discord_webhook="https://discord.com/api/webhooks/..."

vault kv put secrets/infra/srv-26/ntfy \
  auth_token="your-ntfy-token"

vault kv put secrets/infra/srv-26/github-runner \
  token="ghp_xxxxxxxxxxxx" \
  owner="your-gh-org" \
  repository="your-repo"

# srv-27 secrets
vault kv put secrets/infra/srv-27/technitium \
  password="your-technitium-admin-password"

vault kv put secrets/infra/srv-27/observability \
  grafana_admin_password="your-grafana-password" \
  prometheus_retention="30d" \
  influxdb_admin_password="your-influxdb-password"

# srv-28 secrets
vault kv put secrets/infra/srv-28/homeassistant \
  api_token="your-ha-token" \
  latitude="43.6532" \
  longitude="-79.3832"

vault kv put secrets/infra/srv-28/matterbridge \
  irc_password="your-irc-password" \
  slack_token="xoxb-xxxxxxxxxxxx"

vault kv put secrets/infra/srv-28/voip \
  admin_password="your-freepbx-password" \
  db_password="your-mariadb-password" \
  sip_password="your-sip-secret"
```

## Automation via bootstrap.yml

The `bootstrap.yml` playbook automates all of the above steps when provided a valid Vault token:

```bash
ansible-playbook infrastructure/always-on/ansible/bootstrap.yml \
  --extra-vars "vault_token=hvs.xxxxx" \
  --ask-become-pass
```

The bootstrap playbook:
1. Creates/updates all policies
2. Enables AppRole auth if not already enabled
3. Creates or updates each AppRole
4. Generates role-id and secret-id
5. Writes role-id and secret-id directly to each machine over SSH (never stored locally)
6. Applies all Ansible roles (common, docker, netplan, vault-agent, portainer)

## Notes

- **Secret IDs are ephemeral**: They should never be stored in Git or on the operator's laptop. The bootstrap playbook generates them and writes them directly to the target machine via SSH.
- **Role IDs are public**: They can be stored in Git or documentation.
- **Renewal**: Token and secret-id are renewable when vault-agent is running. Monitor token expiry and regenerate secret-ids periodically if needed.
