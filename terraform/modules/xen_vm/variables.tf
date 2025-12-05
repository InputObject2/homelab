variable "hostname" {
  type = string
}
variable "username" {
  type    = string
  default = "cloud-user"
}
variable "public_ssh_key" {
  type = string
}
variable "dns_domain_name" {
  type = string
}
variable "cpu_count" {
  type    = number
  default = 1
}
variable "memory_gb" {
  type    = number
  default = 1
}
variable "disk_size" {
  type    = number
  default = 10
}
variable "xo_template_uuid" {
  type = string
}
variable "xo_sr_id" {
  type = string
}
variable "xo_network_name" {
  type = string
}
variable "xo_pool_name" {
  type = string
}
variable "expected_cidr" {
  type = string
}
variable "start_delay" {
  type    = number
  default = 0
}
variable "tags" {
  type    = list(string)
  default = []
}
variable "mac_prefix" {
  description = "The MAC address prefix to use for generated MAC addresses."
  type        = list(number)
  default     = [0, 22, 62]
}
variable "cloud_init_version" {
  description = "The cloud-init version to use in the cloud-config."
  type        = string
  default     = "v1"
  validation {
    condition     = var.cloud_init_version == "v1" || var.cloud_init_version == "v2"
    error_message = "The cloud_init_version must be either 'v1' or 'v2'."
  }
}
variable "extra_cloud_config_packages" {
  description = "Additional packages to install via cloud-init."
  type        = list(string)
  default     = []
}
variable "extra_cloud_config_commands" {
  description = "Additional commands to run via cloud-init."
  type        = list(string)
  default     = []
}
variable "extra_cloud_config_write_files" {
  description = "Additional files to write via cloud-init."
  type = list(object({
    path        = string
    permissions = string
    content     = string
  }))
  default = []
}
variable "override_cloud_config_template" {
  description = "Override template for the cloud-config."
  type        = string
  default     = null
}