/*
module "cloud_config" {
  source = "./modules/cloud_config"

  hostname           = var.hostname
  username           = var.username == null ? "cloud-user" : var.username
  public_ssh_key     = var.public_ssh_key
  cloud_init_version = var.cloud_init_version
  mac_address        = var.cloud_init_version == "v1" ? "" : module.mac_address.result
}
*/

module "cloud_config" {
  source = "./modules/cloud_config"

  hostname           = var.hostname
  username           = var.username == null ? "cloud-user" : var.username
  public_ssh_key     = var.public_ssh_key
  cloud_init_version = var.cloud_init_version
  mac_address        = var.cloud_init_version == "v1" ? "" : module.mac_address.result

  extra_packages = var.extra_cloud_config_packages
  extra_runcmd = var.extra_cloud_config_commands
  extra_write_files = var.extra_cloud_config_write_files
  override_template = var.override_cloud_config_template
  }



module "mac_address" {
  source     = "./modules/mac_address"
  mac_prefix = var.mac_prefix
}

module "virtual_machine" {
  source = "./modules/virtual_machine"

  hostname             = var.hostname
  hostname_description = "${var.hostname}.${var.dns_domain_name}"

  cloud_config         = module.cloud_config.cloud_config_template
  cloud_network_config = module.cloud_config.cloud_network_config_template
  mac_address          = module.mac_address.result

  cpu_count = var.cpu_count
  memory_gb = var.memory_gb
  disk_size = var.disk_size

  xo_template_uuid = var.xo_template_uuid
  xo_sr_id         = var.xo_sr_id
  xo_network_id    = data.xenorchestra_network.this.id
  expected_cidr    = var.expected_cidr
  auto_poweron     = true
  start_delay      = var.start_delay
  tags             = var.tags
}

module "dns_records" {
  source = "./modules/dns"

  hostname        = module.virtual_machine.name
  dns_domain_name = var.dns_domain_name
  ttl             = 300
  ip_address      = module.virtual_machine.ip_address
}

locals {
  ip_with_cidr = "${module.virtual_machine.ip_address}/${split("/",cidrsubnet(var.expected_cidr, 0, 0))[1]}"
}

/* module "netbox_info" {
  source = "./modules/netbox"

  hostname      = var.hostname
  ip_address    = local.ip_with_cidr
  xo_vm_uuid    = module.virtual_machine.uuid
  xo_cluster_name = var.xo_pool_name
  mac_address   = module.mac_address.result
  cloud_config = module.cloud_config.cloud_config_template
  network_config = module.cloud_config.cloud_network_config_template
} */
