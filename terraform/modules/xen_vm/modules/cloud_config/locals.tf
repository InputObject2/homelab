locals {

  cloud_network_config_template_v1 = <<-EOT
network:
  version: 1
  config:
  - type: physical
    name: eth0
    subnets:
    - type: dhcp
    EOT

  cloud_network_config_template_v2 = <<-EOT
{
  "version": 2,
  "ethernets": {
    "eth0": {
      "dhcp4": true,
      "match": {
        "macaddress": "${var.mac_address}"
      },
      "set-name": "eth0"
    }
  }
}
    EOT

  cloud_network_config_template = var.cloud_init_version == "v1" ? local.cloud_network_config_template_v1 : local.cloud_network_config_template_v2

  base_packages = [
    "unattended-upgrades"
  ]

  base_runcmd = [
    "wget https://github.com/xenserver/xe-guest-utilities/releases/download/v8.4.0/xe-guest-utilities_8.4.0-1_amd64.deb",
    "dpkg -i xe-guest-utilities_8.4.0-1_amd64.deb"
  ]

  # Merge defaults + user extensions
  final_packages = concat(local.base_packages, var.extra_packages)
  final_runcmd   = concat(local.base_runcmd, var.extra_runcmd)

  # Write apt unattended-upgrades config files if auto_update_enable is true
  auto_update_files = var.auto_update_enable ? [
    {
      path        = "/etc/apt/apt.conf.d/20auto-upgrades"
      permissions = "0644"
      content     = <<-EOT
        APT::Periodic::Update-Package-Lists "1";
        APT::Periodic::Download-Upgradeable-Packages "1";
        APT::Periodic::AutocleanInterval "7";
        APT::Periodic::Unattended-Upgrade "1";
        EOT
    },
    {
      path        = "/etc/apt/apt.conf.d/51unattended-upgrades-schedule"
      permissions = "0644"
      content     = <<-EOT
        Unattended-Upgrade::Automatic-Reboot "true";
        Unattended-Upgrade::Automatic-Reboot-Time "${var.auto_update_scheduled_time}";
        EOT
    },
  ] : []

  # Build /etc/cloud-init-setup.conf if runner config is supplied
  runner_conf_file = var.cloud_init_runner_config != null ? [{
    path        = "/etc/cloud-init-setup.conf"
    permissions = "0600"
    content     = <<-EOT
      S3_ENDPOINT="${var.cloud_init_runner_config.s3_endpoint}"
      S3_BUCKET="${var.cloud_init_runner_config.s3_bucket}"
      S3_ACCESS_KEY="${var.cloud_init_runner_config.s3_access_key}"
      S3_SECRET_KEY="${var.cloud_init_runner_config.s3_secret_key}"
      S3_EXPIRES="604800"

      DISCORD_WEBHOOK="${var.cloud_init_runner_config.discord_webhook}"

      LOG_FILE="/var/log/cloud-init-setup.log"
      LOG_LEVEL=1

      EXTRA_LOG_PATHS=""
      EXTRA_PING_HOSTS=""
      EXTRA_DNS_HOSTS="google.com,cloudflare.com"
      EOT
  }] : []

  final_write_files = concat(local.auto_update_files, local.runner_conf_file, var.extra_write_files)

}
