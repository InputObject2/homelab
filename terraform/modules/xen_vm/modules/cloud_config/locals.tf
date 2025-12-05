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

  final_write_files = var.extra_write_files

}