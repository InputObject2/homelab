output "name" {
  description = "The name label of the XenOrchestra VM."
  value       = xenorchestra_vm.this.name_label
}

output "uuid" {
  description = "The UUID of the XenOrchestra VM."
  value       = xenorchestra_vm.this.id
}

output "ip_address" {
  description = "The primary IPv4 address assigned to the VM."
  value       = xenorchestra_vm.this.ipv4_addresses[0]
}

output "affinity_host" {
  description = "The affinity host UUID for the VM, if set."
  value       = xenorchestra_vm.this.affinity_host
}
