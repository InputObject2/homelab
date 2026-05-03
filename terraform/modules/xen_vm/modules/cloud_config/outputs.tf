output "cloud_config_template" {
  description = "The rendered cloud-init user-data template."
  value       = xenorchestra_cloud_config.this.template
}

output "cloud_config_name" {
  description = "The name of the XenOrchestra cloud config resource."
  value       = xenorchestra_cloud_config.this.name
}

output "cloud_network_config_template" {
  description = "The rendered cloud-init network config template."
  value       = local.cloud_network_config_template
}

output "debug" {
  description = "Full rendered cloud-init config for debugging (sensitive values exposed)."
  value       = nonsensitive(local.cloud_config)
  sensitive   = false
}
