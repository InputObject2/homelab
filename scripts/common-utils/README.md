# Cloud-Init Setup Scripts

A comprehensive suite of diagnostic and setup scripts designed to run during VM initialization in XCP-ng via cloud-init. These scripts automatically collect system diagnostics, upload them to an S3-compatible endpoint (like MinIO or Rustfs), and send status notifications to Discord.

## Features

- **Modular Diagnostic Collectors**: Separate collectors for cloud-init logs, journald, dmesg, system info, packages, networking, and disk I/O
- **Automatic Log Aggregation**: Combines all diagnostics into a single compressed tarball
- **S3-Compatible Upload**: Uploads logs to MinIO, Rustfs, AWS S3, or any S3-compatible endpoint
- **Pre-signed URLs**: Generates time-limited access URLs for secure log sharing
- **Discord Integration**: Sends rich formatted notifications with status, links, and system information
- **Error Handling & Retry Logic**: Built-in exponential backoff and graceful failure handling
- **Comprehensive Logging**: All operations logged to `/var/log/cloud-init-setup.log`
- **Ubuntu Support**: Tested on Ubuntu 20.04, 24.04, and 25.10

## Architecture

```
scripts/
├── common-utils/
│   ├── lib/
│   │   └── common.sh                    # Shared utility functions
│   ├── must-gather/
│   │   ├── must-gather.sh              # Main orchestration script (legacy)
│   │   └── collectors/
│   │       ├── cloud-init.sh           # Cloud-init logs
│   │       ├── journald.sh             # Journal logs
│   │       ├── dmesg.sh                # Kernel messages
│   │       ├── logfiles.sh             # System logs
│   │       ├── networking.sh           # Network diagnostics
│   │       ├── system-info.sh          # System information
│   │       ├── packages.sh             # Package manager info
│   │       └── disk-io.sh              # Disk and I/O stats
│   ├── notifier/
│   │   └── discord-notifier.sh         # Discord notification sender
│   ├── s3-uploader/
│   │   └── upload.sh                   # S3 upload and presign utility
│   ├── cloud-init-runner.sh            # Main orchestrator (cloud-init friendly)
│   └── cloud-init-setup.conf.template  # Configuration template
```

## Quick Start

### 1. Configuration

Create a configuration file with your S3 and Discord credentials:

```bash
cat > /etc/cloud-init-setup.conf <<'EOF'
# S3 / MinIO / Rustfs Configuration
S3_ENDPOINT="https://rustfs.example.com"
S3_BUCKET="cloud-init-logs"
S3_ACCESS_KEY="your-access-key"
S3_SECRET_KEY="your-secret-key"
S3_EXPIRES="604800"  # 7 days

# Discord Webhook
DISCORD_WEBHOOK="https://discord.com/api/webhooks/XXXXX/XXXXX"

# Logging
LOG_FILE="/var/log/cloud-init-setup.log"
LOG_LEVEL=1  # 0=DEBUG, 1=INFO, 2=WARN, 3=ERROR

# Optional diagnostics
EXTRA_PING_HOSTS="192.168.1.1,10.0.0.1"
EXTRA_DNS_HOSTS="internal.example.com,external.example.com"
EOF
```

### 2. Via Cloud-Init (Terraform)

In your Terraform XEN VM module, pass configuration as environment variables or via cloud-init:

```hcl
locals {
  cloud_init_config = {
    hostname           = var.hostname
    username           = "ubuntu"
    public_ssh_key     = var.public_ssh_key
    packages           = ["curl", "git", "jq", "awscli", "lsof"]

    script_repo_url    = "https://github.com/inputobject2/homelab.git"
    script_repo_branch = "main"
    script_download_dir = "/opt/cloud-init-scripts"

    # Optional: download config from URL
    script_config_url  = "https://example.com/cloud-init-setup.conf"
    script_config_file = "/etc/cloud-init-setup.conf"
  }
}
```

The cloud-init template will:
1. Download the setup scripts from your GitHub repository
2. Make scripts executable
3. Download configuration file (if provided)
4. Run `cloud-init-runner.sh` to collect and upload diagnostics

### 3. Manual Execution

To run diagnostics collection and upload manually:

```bash
# Full run with all collectors
/opt/cloud-init-scripts/scripts/common-utils/cloud-init-runner.sh \
  --config /etc/cloud-init-setup.conf

# Collection only (no upload/notify)
/opt/cloud-init-scripts/scripts/common-utils/cloud-init-runner.sh \
  --config /etc/cloud-init-setup.conf \
  --collect-only

# Skip specific collectors
/opt/cloud-init-scripts/scripts/common-utils/cloud-init-runner.sh \
  --config /etc/cloud-init-setup.conf \
  --skip-collectors "disk-io,packages"

# Only run specific collectors
/opt/cloud-init-scripts/scripts/common-utils/cloud-init-runner.sh \
  --config /etc/cloud-init-setup.conf \
  --include-collectors "cloud-init,journald,networking"

# Skip upload and notification (debug mode)
/opt/cloud-init-scripts/scripts/common-utils/cloud-init-runner.sh \
  --config /etc/cloud-init-setup.conf \
  --skip-upload \
  --skip-notify
```

## Individual Collectors

Each collector generates a separate tarball in the staging directory:

### cloud-init.sh
Collects cloud-init logs and configuration:
- `/var/log/cloud-init.log`
- `/var/log/cloud-init-output.log`
- `/run/cloud-init/`
- `/etc/cloud/`
- `cloud-init collect-logs` output

### journald.sh
Collects system journal logs:
- Current boot messages (all levels)
- Current boot warnings and above
- Last 1000 lines from all boots
- Systemd unit failure summary

### dmesg.sh
Collects kernel messages:
- Raw dmesg output
- Human-readable timestamps
- Kernel messages from journald

### logfiles.sh
Collects system log files (default: `/var/log`):
- All log files in `/var/log` directory
- Supports custom paths via `--paths` parameter

### networking.sh
Network diagnostics:
- IP address configuration
- Routing table and ARP cache
- Socket statistics
- DNS resolution
- Connectivity tests (ping to default gateway, internet hosts)
- Optional custom hosts for ping/DNS testing

### system-info.sh
System information:
- uname, lsb_release, os-release
- Time and date configuration
- CPU, memory, disk info
- Process list and top output
- Package manager listings
- Systemd status and failed units
- SELinux/AppArmor status
- System configuration files (hostname, fstab, etc.)

### packages.sh
Package manager information:
- Installed packages list (dpkg/rpm)
- Upgradable packages
- Snap/flatpak/pip/npm packages
- Docker/Podman container info

### disk-io.sh
Disk and I/O diagnostics:
- Disk usage analysis
- Partition and device info
- LVM information (if present)
- RAID status (if present)
- I/O statistics (iostat)
- Optional FIO performance testing

## Discord Notifications

The notifier sends rich embeds with:
- Title and description
- Status indicator (success/error/warning/info with color coding)
- Hostname and timestamp
- Pre-signed URL for log download
- Custom fields for additional information
- Footer with orchestrator info

### Status Colors
- **Green (success)**: All diagnostics collected and uploaded successfully
- **Red (error)**: One or more operations failed
- **Yellow (warning)**: Partial success or non-critical issues
- **Blue (info)**: Informational messages

Example notification:
```
┌─────────────────────────────────────┐
│ Cloud-Init Setup vm-hostname         │
├─────────────────────────────────────┤
│ Diagnostics collection and upload   │
│ completed                            │
│                                     │
│ Hostname:    vm-hostname            │
│ Status:      success                │
│ Timestamp:   2024-01-25T15:30:00Z   │
│ Diagnostics: [Download Logs]        │
└─────────────────────────────────────┘
```

## S3 Configuration Examples

### MinIO
```bash
S3_ENDPOINT="https://minio.example.com:9000"
S3_BUCKET="cloud-init-logs"
S3_ACCESS_KEY="minioadmin"
S3_SECRET_KEY="minioadmin"
```

### Rustfs
```bash
S3_ENDPOINT="https://rustfs.example.com"
S3_BUCKET="diagnostics"
S3_ACCESS_KEY="your-access-key"
S3_SECRET_KEY="your-secret-key"
```

### AWS S3
```bash
S3_ENDPOINT="https://s3.amazonaws.com"
S3_BUCKET="my-diagnostics-bucket"
S3_ACCESS_KEY="AKIAIOSFODNN7EXAMPLE"
S3_SECRET_KEY="wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
```

## Common Issues & Troubleshooting

### Scripts not downloading
- Check GitHub URL and branch name
- Verify network connectivity during cloud-init
- Check `/var/log/cloud-init.log` for errors

### Upload fails
- Verify S3 credentials and endpoint
- Check network connectivity to S3 endpoint
- Ensure S3 bucket exists and is accessible
- Review logs in `/var/log/cloud-init-setup.log`

### Discord notifications not sent
- Verify Discord webhook URL is correct
- Check network connectivity to Discord API
- Review logs for webhook response errors

### Insufficient disk space
- Collectors may require 100-500MB depending on log verbosity
- Check available space: `df -h`
- Skip large collectors if needed: `--skip-collectors packages,disk-io`

### Collection takes too long
- Skip slow collectors: `--skip-collectors disk-io` (FIO test)
- Use `--collect-only --skip-upload --skip-notify` for debugging
- Check for hung processes: `ps auxf | grep -E 'cloud-init|collector'`

## Integration with Terraform

Example module variables:

```hcl
variable "enable_diagnostics" {
  type    = bool
  default = true
  description = "Enable cloud-init diagnostics collection"
}

variable "s3_endpoint" {
  type        = string
  description = "S3-compatible endpoint for log upload"
}

variable "s3_bucket" {
  type        = string
  default     = "cloud-init-logs"
  description = "S3 bucket for diagnostics"
}

variable "discord_webhook" {
  type        = string
  sensitive   = true
  description = "Discord webhook for notifications"
}

variable "script_repo_url" {
  type    = string
  default = "https://github.com/inputobject2/homelab.git"
  description = "Repository URL for setup scripts"
}

variable "script_repo_branch" {
  type    = string
  default = "main"
  description = "Repository branch to clone"
}
```

## Advanced Usage

### Custom Diagnostics Path

Pass additional paths to collect in the `EXTRA_LOG_PATHS` configuration:

```bash
EXTRA_LOG_PATHS="/opt/app/logs,/var/opt/custom-service/logs"
```

### Environment Variables Override

All configuration can be overridden via environment variables:

```bash
export S3_ENDPOINT="https://custom-endpoint.com"
export DISCORD_WEBHOOK="https://discord.com/api/webhooks/..."
/opt/cloud-init-scripts/scripts/common-utils/cloud-init-runner.sh
```

### Dry Run

Test without uploading or notifying:

```bash
/opt/cloud-init-scripts/scripts/common-utils/cloud-init-runner.sh \
  --config /etc/cloud-init-setup.conf \
  --skip-upload \
  --skip-notify
```

### Debug Mode

Enable debug logging:

```bash
export LOG_LEVEL=0  # DEBUG
/opt/cloud-init-scripts/scripts/common-utils/cloud-init-runner.sh \
  --config /etc/cloud-init-setup.conf
```

## File Locations

- **Main orchestrator**: `/opt/cloud-init-scripts/scripts/common-utils/cloud-init-runner.sh`
- **Collectors**: `/opt/cloud-init-scripts/scripts/common-utils/must-gather/collectors/`
- **Configuration**: `/etc/cloud-init-setup.conf`
- **Logs**: `/var/log/cloud-init-setup.log`
- **Staging directory**: `/tmp/cloud-init-staging-$PID/`
- **Final tarball**: `/var/log/cloud-init-diagnostics-HOSTNAME-TIMESTAMP.tar.gz`

## Supported Platforms

- Ubuntu 20.04 LTS
- Ubuntu 24.04 LTS
- Ubuntu 25.10
- Other Debian-based distributions (apt-based)

## Dependencies

- `curl` - Download scripts and upload files
- `git` - Clone repository (fallback to tar.gz download)
- `tar` - Compress diagnostics
- `jq` - JSON processing (optional)
- `awscli` - S3 operations
- Standard utilities: `sed`, `awk`, `grep`, `find`, etc.

All dependencies are automatically installed via the cloud-init template.

## Security Considerations

- **API Keys**: Store S3 credentials in secure configuration files with appropriate file permissions
- **Pre-signed URLs**: Default 7-day expiration, configurable via `S3_EXPIRES`
- **Webhook URLs**: Mark Discord webhook as sensitive in Terraform to avoid exposure in logs
- **Log Files**: Contain system information; store securely and rotate regularly
- **Configuration Files**: Include credentials; protect with restrictive file permissions (600)

## Contributing

To add new collectors or features:

1. Create new collector script in `scripts/common-utils/must-gather/collectors/`
2. Follow naming convention: `COLLECTOR_NAME.sh`
3. Implement standard interface: `--output-dir` parameter, output tarball to stdout
4. Update `cloud-init-runner.sh` collector list
5. Test in isolated environment

## License

See root repository LICENSE file.
