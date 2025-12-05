output "name" {
  value = xenorchestra_vm.this.name_label
}

output "uuid" {
  value = xenorchestra_vm.this.id
}

output "ip_address" {
  value = xenorchestra_vm.this.ipv4_addresses[0]
}

output "affinity_host" {
  value = xenorchestra_vm.this.affinity_host
}