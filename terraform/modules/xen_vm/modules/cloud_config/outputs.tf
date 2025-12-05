output "cloud_config_template" {
  value = xenorchestra_cloud_config.this.template
}

output "cloud_config_name" {
  value = xenorchestra_cloud_config.this.name
}

output "cloud_network_config_template" {
  value = local.cloud_network_config_template
}

output "debug" {
  value = nonsensitive(local.cloud_config)
  sensitive = false
}