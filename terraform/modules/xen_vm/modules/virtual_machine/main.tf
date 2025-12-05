resource "xenorchestra_vm" "this" {
  name_label           = var.hostname
  cloud_config         = var.cloud_config
  cloud_network_config = var.cloud_network_config
  template             = var.xo_template_uuid
  auto_poweron         = var.auto_poweron

  name_description = var.hostname_description

  network {
    network_id       = var.xo_network_id
    mac_address      = var.mac_address
    expected_ip_cidr = var.expected_cidr
  }

  disk {
    sr_id      = var.xo_sr_id
    name_label = "${var.hostname}-os"
    size       = var.disk_size * 1024 * 1024 * 1024 # GB to B
  }

  cpus       = var.cpu_count
  memory_max = var.memory_gb * 1024 * 1024 * 1024 # GB to B

  start_delay                         = var.start_delay
  destroy_cloud_config_vdi_after_boot = false

  tags = var.tags

  lifecycle {
    ignore_changes = [disk, affinity_host, template]
  }
}
