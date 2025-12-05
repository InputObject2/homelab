data "netbox_cluster" "cluster" {
  name = var.xo_cluster_name
}

resource "netbox_virtual_machine" "this" {
  name       = var.hostname
  status     = "active"
  cluster_id = data.netbox_cluster.cluster.id

  # If the plugin has a custom field for XO UUID:
  custom_fields = {
  uuid = var.xo_vm_uuid
  }

  local_context_data = jsonencode({
    "network-config" = var.network_config,
    "cloud-init-config" = var.cloud_config
    })
}

resource "netbox_interface" "this" {
  virtual_machine_id = netbox_virtual_machine.this.id
  name               = "eth0"
  mac_address        = var.mac_address
  enabled            = true
}

resource "netbox_ip_address" "ip" {
  virtual_machine_interface_id =  netbox_interface.this.id
  ip_address            = var.ip_address
  status             = "active"
}
