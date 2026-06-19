# Pass-through from the base network module
output "vlan_id" {
  description = "VLAN ID allocated for this cluster."
  value       = module.network.vlan_id
}

output "network_uuid" {
  description = "UUID of the XenOrchestra network."
  value       = module.network.network_uuid
}

output "network_name" {
  description = "Display name of the XenOrchestra network (pass this to the microk8s cluster module as xoa_network_name)."
  value       = module.network.network_name
}

output "network_cidr" {
  description = "CIDR of the allocated subnet (pass this to the microk8s cluster module as *_expected_cidr)."
  value       = module.network.network_cidr
}

output "gateway_ip" {
  description = "IP address of the gateway."
  value       = module.network.gateway_ip
}

# MicroK8s-specific: pre-allocated addresses and MACs
output "master_ips" {
  description = "Pre-allocated IP addresses for control-plane nodes (index-stable)."
  value       = [for i in range(var.master_count) : cidrhost(module.network.network_cidr, var.master_ip_start + i)]
}

output "node_ips" {
  description = "Pre-allocated IP addresses for worker nodes (index-stable)."
  value       = [for i in range(var.node_count) : cidrhost(module.network.network_cidr, var.node_ip_start + i)]
}

output "master_mac_addresses" {
  description = "Pre-generated MAC addresses for control-plane nodes (index-stable). Pass to the microk8s cluster module as master_mac_addresses so VMs get the MACs that match their DHCP leases."
  value       = [for m in macaddress.master : upper(m.address)]
}

output "prefix_length" {
  description = "Prefix length of the allocated subnet (e.g. 24)."
  value       = module.network.prefix_length
}

output "node_mac_addresses" {
  description = "Pre-generated MAC addresses for worker nodes (index-stable). Pass to the microk8s cluster module as node_mac_addresses so VMs get the MACs that match their DHCP leases."
  value       = [for m in macaddress.node : upper(m.address)]
}
