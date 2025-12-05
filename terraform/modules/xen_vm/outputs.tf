output "name" {
  value = module.virtual_machine.name
}

output "ip_address" {
  value = module.virtual_machine.ip_address
}

output "fqdn" {
  value = "${module.virtual_machine.name}.${var.dns_domain_name}"
}

output "debug" {
  value = module.cloud_config.debug
}