# Always-On Infrastructure

This directory contains the complete implementation spec and automation for the **3 HP T640 thin client always-on infrastructure** running Ubuntu, managed via `ansible-pull` and Portainer.

## Overview

Three machines (`srv-26`, `srv-27`, `srv-28`) form the backbone of the homelab infrastructure, providing:
- **srv-26**: Primary DNS (Technitium), network fabric (Tailscale, Gatus, ntfy), WLAN controller (Omada), GitHub Actions runner
- **srv-27**: Secondary DNS (Technitium, zone transfer from srv-26), observability stack (Prometheus, Grafana, Loki, InfluxDB, Promtail)
- **srv-28**: Home automation (Home Assistant, Matterbridge, python-matter-server, matter-hub, ESPHome, Zigbee2MQTT, Mosquitto), VoIP (FreePBX, TFTP, MariaDB)

## Quick Start

### Prerequisites

1. **Three Ubuntu machines** (20.04 LTS or later) with SSH access
2. **HashiCorp Vault** instance running at a publicly accessible address
3. **Ansible** installed on your operator laptop
4. **SSH keys** configured for the `ansible` user on each machine
5. **GitHub Actions self-hosted runner** on srv-26 (optional, for immediate apply on push)

### Bootstrap (One-Time Operator Task)

1. **Prepare vault_addr and vault_token**
   ```bash
   export VAULT_ADDR="https://vault.yourdomain.com:8200"
   vault login -method=oidc  # or your auth method
   ```

2. **Update `ansible/inventory/group_vars/all.yml`**
   - Set `vault_addr` to your Vault VPS address
   - Update `primary_nic` in `group_vars/srv-28.yml` to match physical NIC name

3. **Create vault secrets** (populate these with real values):
   ```bash
   vault kv put secrets/infra/srv-26/technitium password="xxx"
   vault kv put secrets/infra/srv-26/tailscale authkey="xxx"
   vault kv put secrets/infra/srv-26/omada admin_password="xxx"
   vault kv put secrets/infra/srv-26/gatus discord_webhook="xxx"
   vault kv put secrets/infra/srv-26/ntfy auth_token="xxx"
   vault kv put secrets/infra/srv-26/github-runner \
     token="ghp_xxxxxxxxxxxx" \
     owner="your-gh-org" \
     repository="your-repo"
   vault kv put secrets/infra/srv-27/technitium password="xxx"
   vault kv put secrets/infra/srv-27/observability \
     grafana_admin_password="xxx" \
     prometheus_retention="30d" \
     influxdb_admin_password="xxx"
   vault kv put secrets/infra/srv-28/homeassistant \
     api_token="xxx" \
     latitude="43.6532" \
     longitude="-79.3832"
   vault kv put secrets/infra/srv-28/matterbridge \
     irc_password="xxx" \
     slack_token="xxx"
   vault kv put secrets/infra/srv-28/voip \
     freepbx_admin_password="xxx" \
     db_password="xxx" \
     sip_password="xxx"
   ```

4. **Run bootstrap.yml** from your operator laptop:
   ```bash
   cd homelab
   ansible-playbook infrastructure/always-on/ansible/bootstrap.yml \
     --extra-vars "vault_token=$(vault print token)" \
     --ask-become-pass
   ```

   The bootstrap playbook will:
   - Create Vault policies and AppRoles
   - Apply common, docker, netplan, vault-agent, and portainer roles to all machines
   - Write AppRole credentials directly to each machine over SSH (never stored locally)
   - Start vault-agent and Portainer containers

5. **Verify Deployment**
   ```bash
   # Check vault-agent is running
   ssh ansible@srv-26 docker ps | grep vault-agent

   # Check secrets were created
   ssh ansible@srv-26 ls -la /opt/secrets/*/

   # Access Portainer
   https://srv-26:9443
   ```

## Repository Structure

```
infrastructure/always-on/
├── ansible/                     # Ansible automation
│   ├── ansible.cfg             # Ansible config
│   ├── bootstrap.yml           # One-time bootstrap playbook
│   ├── site.yml                # ansible-pull entry point
│   ├── inventory/              # Hosts and variables
│   │   ├── hosts.yml
│   │   └── group_vars/
│   │       ├── all.yml
│   │       ├── srv-26.yml
│   │       ├── srv-27.yml
│   │       └── srv-28.yml
│   └── roles/                  # Reusable Ansible roles
│       ├── common/             # SSH harden, UFW, ansible-pull timer
│       ├── docker/             # Install Docker + create base dirs
│       ├── netplan/            # Network config (single NIC or VLAN)
│       ├── vault-agent/        # Deploy vault-agent container
│       └── portainer/          # Deploy Portainer server/agent
│
├── stacks/                     # Docker Compose workloads (managed by Portainer)
│   ├── srv-26/
│   │   ├── dns/docker-compose.yml       # Technitium DNS
│   │   ├── infra/docker-compose.yml     # Tailscale, Gatus, ntfy
│   │   ├── wlan/docker-compose.yml      # Omada controller
│   │   └── cicd/docker-compose.yml      # GitHub Actions runner
│   ├── srv-27/
│   │   ├── dns/docker-compose.yml       # Technitium DNS (secondary)
│   │   └── observability/docker-compose.yml  # Prometheus, Grafana, Loki, InfluxDB, Promtail
│   └── srv-28/
│       ├── ha/docker-compose.yml        # Home Assistant, Matterbridge, Matter, ESPHome, Zigbee2MQTT, Mosquitto
│       └── voip/docker-compose.yml      # FreePBX, TFTP, MariaDB
│
├── vault/                      # Vault configuration
│   ├── policies/               # Vault policies (shared, srv-26, srv-27, srv-28)
│   └── APPROLES.md            # Manual AppRole setup guide
│
└── vault-agent/               # vault-agent configurations and templates
    ├── config/                # Vault agent HCL configs
    │   ├── srv-26.hcl
    │   ├── srv-27.hcl
    │   └── srv-28.hcl
    └── templates/             # Vault template files for secrets
        ├── srv-26/
        ├── srv-27/
        └── srv-28/
```

## Operations

### Day-to-Day Updates

**For OS-level changes:**
- Edit `ansible/roles/*/tasks/main.yml` or inventory variables
- Push to main branch
- ansible-pull runs every 15 minutes on each machine, applies automatically
- Or manually trigger: `ssh ansible@srv-host sudo systemctl start ansible-pull.service`

**For Docker/application changes:**
- Edit the relevant `stacks/<hostname>/<stack>/docker-compose.yml`
- Each stack is registered independently in Portainer as a Git-backed stack
- Portainer stack path format: `infrastructure/always-on/stacks/<hostname>/<stack>`
- Push to main branch and trigger a pull in Portainer, or let auto-sync run

**For new secrets:**
- Add to Vault: `vault kv put secrets/infra/srv-xx/app-name key=value`
- Create template in `vault-agent/templates/srv-xx/app-name.tpl`
- Reference in `vault-agent/config/srv-xx.hcl`
- Restart vault-agent: `docker restart vault-agent`

### Monitoring

- **Grafana**: http://srv-27:3000/
- **Prometheus**: http://srv-27:9090/
- **Loki**: http://srv-27:3100/
- **Portainer**: https://srv-26:9443/
- **Home Assistant**: (depends on config, usually http://srv-28:8123/)

### Troubleshooting

**vault-agent not running?**
```bash
ssh ansible@srv-26
docker logs vault-agent
cat /opt/vault-agent/config.hcl
cat /opt/vault-agent/role-id
cat /opt/vault-agent/secret-id
```

**Secrets not written?**
Check vault-agent logs and verify Vault connectivity:
```bash
docker exec vault-agent vault status
docker exec vault-agent vault list secrets/data/infra/srv-26/
```

**ansible-pull failing?**
```bash
ssh ansible@srv-26
sudo systemctl status ansible-pull.timer
sudo journalctl -u ansible-pull.service -n 50
```

**Portainer agent unreachable?**
Ensure UFW allows port 9001 and the agent container is running:
```bash
ssh ansible@srv-27
docker ps | grep portainer-agent
docker logs portainer-agent
```

## Security Considerations

1. **Secret IDs are ephemeral**: Never commit them to Git. They are generated during bootstrap and written directly to each machine over SSH.
2. **SSH hardening**: Passwords disabled, root login disabled. Use SSH keys only.
3. **Firewall**: UFW enabled on all machines. SSH and Portainer agent port allowed explicitly.
4. **Vault AppRole token TTLs**: Set to 1h with max TTL 4h. Periodically rotate secret-ids.
5. **Network isolation**: srv-28 has a separate VLAN30 for IoT devices (no default route).

## GitHub Actions Workflow

An optional workflow at `.github/workflows/apply-always-on.yml` triggers ansible-pull immediately on push to `infrastructure/always-on/`. This requires:
- GitHub Actions self-hosted runner running on srv-26
- SSH keys configured between srv-26 and srv-27/srv-28

## References

- Full spec: [Always-On Infrastructure Spec](../../docs/always-on-spec.md)
- Vault documentation: https://www.vaultproject.io/docs
- Ansible documentation: https://docs.ansible.com/
- Portainer documentation: https://docs.portainer.io/
