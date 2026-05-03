variable "hostname" {
  description = "The hostname to set in the cloud-config."
  type        = string
}

variable "username" {
  description = "The username to create in the cloud-config."
  type        = string
  default     = "cloud-user"
}

variable "public_ssh_key" {
  description = "The public SSH key to add to the cloud-config user."
  type        = string
}

variable "cloud_init_version" {
  description = "The cloud-init version to use in the cloud-config."
  type        = string
  default     = "v1"
}

variable "mac_address" {
  description = "MAC address for the VM network interface."
  type        = string
  default     = ""
}

variable "extra_packages" {
  description = "Additional packages to install via cloud-init."
  type        = list(string)
  default     = []
}

variable "extra_runcmd" {
  description = "Additional runcmd entries to append to the default cloud-init commands."
  type        = list(string)
  default     = []
}

variable "extra_write_files" {
  description = "Additional write_files entries to include in the cloud-init config."
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

variable "override_template" {
  type        = string
  default     = null
  description = "If provided, replaces the entire cloud-init template"
}
variable "cloud_init_runner_config" {
  description = "When set, writes /etc/cloud-init-setup.conf for the cloud-init runner."
  type = object({
    s3_endpoint     = string
    s3_bucket       = string
    s3_access_key   = string
    s3_secret_key   = string
    discord_webhook = string
  })
  default = null
}
