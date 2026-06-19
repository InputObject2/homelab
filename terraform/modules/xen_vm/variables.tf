variable "hostname" {
  description = "The hostname to assign to the VM."
  type        = string
}
variable "username" {
  description = "The OS user to create via cloud-init."
  type        = string
  default     = "cloud-user"
}
variable "public_ssh_key" {
  description = "Public SSH key to add to the cloud-init user's authorized_keys."
  type        = string
}
variable "dns_domain_name" {
  description = "DNS domain used for A record creation and FQDN construction."
  type        = string
}
variable "cpu_count" {
  description = "Number of vCPUs to assign to the VM."
  type        = number
  default     = 1
}
variable "memory_gb" {
  description = "Amount of memory in GiB to assign to the VM."
  type        = number
  default     = 1
}
variable "disk_size" {
  description = "Root disk size in GiB."
  type        = number
  default     = 10
}
variable "xo_template_uuid" {
  description = "UUID of the XenOrchestra VM template to clone."
  type        = string
}
variable "xo_sr_id" {
  description = "UUID of the XenOrchestra storage repository for the VM disk."
  type        = string
}
variable "xo_network_name" {
  description = "Name of the XenOrchestra network to attach the VM to."
  type        = string
}
variable "xo_pool_name" {
  description = "Name of the XenOrchestra pool/cluster to deploy the VM in."
  type        = string
}
variable "expected_cidr" {
  description = "CIDR block the VM's IP is expected to fall within (used for IP detection)."
  type        = string
}
variable "start_delay" {
  description = "Seconds to wait before powering on the VM after creation."
  type        = number
  default     = 0
}
variable "tags" {
  description = "List of tags to apply to the XenOrchestra VM."
  type        = list(string)
  default     = []
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
variable "auto_update_enable" {
  description = "Write apt unattended-upgrades config files to enable automatic updates."
  type        = bool
  default     = true
}

variable "auto_update_scheduled_time" {
  description = "Time at which unattended-upgrades will reboot if required (HH:MM, 24-hour)."
  type        = string
  default     = "02:00"
}

variable "override_cloud_config_template" {
  description = "Override template for the cloud-config."
  type        = string
  default     = null
}
variable "cloud_init_runner_config" {
  description = "When set, writes /etc/cloud-init-setup.conf for the cloud-init runner. All five fields are required; omit the variable entirely (leave null) to skip the file."
  type = object({
    s3_endpoint     = string
    s3_bucket       = string
    s3_access_key   = string
    s3_secret_key   = string
    discord_webhook = string
  })
  default = null
}
