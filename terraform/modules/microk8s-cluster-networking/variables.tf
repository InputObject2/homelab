####################################
# Mandatory variables               #
####################################

variable "cluster_name" {
  description = "Short name of the cluster (e.g. 'apps'). Used in Netbox descriptions, DHCP comments, and the XO network label."
  type        = string
}

variable "master_count" {
  description = "Number of control-plane nodes."
  type        = number
}

variable "master_prefix" {
  description = "Hostname prefix for master nodes (e.g. 'us20-k8s')."
  type        = string
}

variable "node_count" {
  description = "Number of worker nodes."
  type        = number
}

variable "node_prefix" {
  description = "Hostname prefix for worker nodes (e.g. 'us20-k8s')."
  type        = string
}

####################################
# Base network variables            #
# (passed through to modules/network)
####################################

variable "netbox_vlan_group_slug" {
  description = "Slug of the Netbox VLAN group to allocate a VLAN from."
  type        = string
  default     = "microk8s-networks"
}

variable "netbox_parent_prefix" {
  description = "Parent prefix in Netbox from which a /24 will be carved out."
  type        = string
  default     = "10.95.0.0/16"
}

variable "netbox_prefix_length" {
  description = "Prefix length for the allocated subnet."
  type        = number
  default     = 24
}

variable "bridge_name" {
  description = "RouterOS bridge interface the VLAN lives on."
  type        = string
  default     = "bridge-lan"
}

variable "tagged_interfaces" {
  description = "RouterOS interfaces to tag with the new VLAN."
  type        = list(string)
  default     = ["sfp-sfpplus1", "bridge-lan"]
}

variable "untagged_interfaces" {
  description = "RouterOS interfaces to untag with the new VLAN."
  type        = list(string)
  default     = []
}

variable "dns_servers" {
  description = "DNS servers advertised to DHCP clients."
  type        = list(string)
  default     = ["10.222.0.12", "10.222.0.13", "10.222.0.14"]
}

variable "ntp_servers" {
  description = "NTP servers advertised to DHCP clients."
  type        = list(string)
  default     = ["10.222.0.18", "10.222.0.19"]
}

variable "domain" {
  description = "Domain name advertised to DHCP clients (option 15)."
  type        = string
  default     = null
}

variable "xo_pool_name" {
  description = "Name of the Xen Orchestra pool to create the network in."
  type        = string
  default     = "Minis"
}

variable "xo_source_pif_device" {
  description = "Physical interface (PIF) device to attach the XO network to."
  type        = string
  default     = "eth1"
}

####################################
# IP layout variables               #
####################################

variable "gateway_position" {
  description = "Which end of the subnet to use for the gateway: 'first' (.1) or 'last' (.254 for a /24)."
  type        = string
  default     = "first"
  validation {
    condition     = contains(["first", "last"], var.gateway_position)
    error_message = "gateway_position must be either 'first' or 'last'."
  }
}

variable "dhcp_pool_start" {
  description = "First host number for the dynamic DHCP pool."
  type        = number
  default     = 100
}

variable "dhcp_pool_end" {
  description = "Last host number for the dynamic DHCP pool."
  type        = number
  default     = 200
}

variable "master_ip_start" {
  description = "First host number in the subnet to assign to master nodes. Must not overlap with the dynamic DHCP pool."
  type        = number
  default     = 10
  validation {
    condition     = var.master_ip_start >= 2
    error_message = "master_ip_start must be >= 2 (host 0 is the network address, host 1 is the gateway)."
  }
}

variable "node_ip_start" {
  description = "First host number in the subnet to assign to worker nodes. Must not overlap with the dynamic DHCP pool."
  type        = number
  default     = 20
  validation {
    condition     = var.node_ip_start >= 2
    error_message = "node_ip_start must be >= 2 (host 0 is the network address, host 1 is the gateway)."
  }
}
