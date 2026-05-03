output "name" {
  description = "The hostname/name label of the provisioned VM."
  value       = module.virtual_machine.name
}

output "ip_address" {
  description = "The primary IPv4 address of the provisioned VM."
  value       = module.virtual_machine.ip_address
}

output "fqdn" {
  description = "The fully-qualified domain name of the provisioned VM."
  value       = "${module.virtual_machine.name}.${var.dns_domain_name}"
}

output "debug" {
  description = "Full rendered cloud-init config for debugging."
  value       = module.cloud_config.debug
}
