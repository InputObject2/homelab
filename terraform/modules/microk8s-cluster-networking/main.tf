####################################
# Base network                      #
# VLAN + subnet + DHCP pool + XO   #
# network + basic firewall          #
####################################

module "network" {
  source = "../network"

  name = "MicroK8s ${var.cluster_name}"

  # Netbox
  netbox_vlan_group_slug = var.netbox_vlan_group_slug
  netbox_parent_prefix   = var.netbox_parent_prefix
  netbox_prefix_length   = var.netbox_prefix_length

  # IP layout
  gateway_position = var.gateway_position
  dhcp_pool_start  = var.dhcp_pool_start
  dhcp_pool_end    = var.dhcp_pool_end

  # RouterOS
  bridge_name         = var.bridge_name
  tagged_interfaces   = var.tagged_interfaces
  untagged_interfaces = var.untagged_interfaces
  dns_servers         = var.dns_servers
  ntp_servers         = var.ntp_servers
  domain              = var.domain

  # Xen Orchestra
  xo_pool_name         = var.xo_pool_name
  xo_source_pif_device = var.xo_source_pif_device
}

####################################
# IP layout guard                   #
# Cross-variable validation that    #
# static reservations don't overlap #
# with the dynamic DHCP pool or     #
# with each other.                  #
####################################

resource "terraform_data" "ip_layout_guard" {
  lifecycle {
    precondition {
      condition     = var.master_ip_start + var.master_count <= var.dhcp_pool_start
      error_message = "master IP range [${var.master_ip_start}, ${var.master_ip_start + var.master_count - 1}] overlaps with the dynamic DHCP pool starting at ${var.dhcp_pool_start}."
    }
    precondition {
      condition     = var.node_ip_start + var.node_count <= var.dhcp_pool_start
      error_message = "node IP range [${var.node_ip_start}, ${var.node_ip_start + var.node_count - 1}] overlaps with the dynamic DHCP pool starting at ${var.dhcp_pool_start}."
    }
    precondition {
      condition     = var.node_ip_start >= var.master_ip_start + var.master_count || var.master_ip_start >= var.node_ip_start + var.node_count
      error_message = "master IP range [${var.master_ip_start}..${var.master_ip_start + var.master_count - 1}] and node IP range [${var.node_ip_start}..${var.node_ip_start + var.node_count - 1}] overlap."
    }
  }
}

####################################
# Netbox – per-role IP reservations #
####################################

resource "netbox_ip_address" "master" {
  count = var.master_count

  ip_address  = "${cidrhost(module.network.network_cidr, var.master_ip_start + count.index)}/32"
  description = "${var.master_prefix}-${count.index + 1} (MicroK8s control-plane, cluster: ${var.cluster_name})"
  status      = "active"

  lifecycle {
    ignore_changes = [custom_fields]
  }
}

resource "netbox_ip_address" "node" {
  count = var.node_count

  ip_address  = "${cidrhost(module.network.network_cidr, var.node_ip_start + count.index)}/32"
  description = "${var.node_prefix}-${count.index + 1} (MicroK8s worker, cluster: ${var.cluster_name})"
  status      = "active"

  lifecycle {
    ignore_changes = [custom_fields]
  }
}

####################################
# MAC address pre-generation        #
# One per node, stable across       #
# re-applies (ignore_changes).      #
####################################

resource "macaddress" "master" {
  count = var.master_count

  lifecycle {
    ignore_changes = all
  }
}

resource "macaddress" "node" {
  count = var.node_count

  lifecycle {
    ignore_changes = all
  }
}

####################################
# RouterOS – static DHCP leases     #
# Binds each pre-generated MAC to   #
# its reserved IP so the VM always  #
# boots on the right address.       #
####################################

/*
resource "routeros_ip_dhcp_server_lease" "master" {
  count = var.master_count

  address     = cidrhost(module.network.network_cidr, var.master_ip_start + count.index)
  mac_address = upper(macaddress.master[count.index].address)
  server      = module.network.dhcp_server_name
  comment     = "${var.master_prefix}-m-${count.index + 1}"
}

resource "routeros_ip_dhcp_server_lease" "node" {
  count = var.node_count

  address     = cidrhost(module.network.network_cidr, var.node_ip_start + count.index)
  mac_address = upper(macaddress.node[count.index].address)
  server      = module.network.dhcp_server_name
  comment     = "${var.node_prefix}-${count.index + 1}"
}
*/
