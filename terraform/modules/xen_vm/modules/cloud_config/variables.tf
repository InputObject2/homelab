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

variable "extra_cloud_config_packages" {
  description = "Additional packages to install via cloud-config."
  type        = string
  default     = ""
}

variable "extra_cloud_config_commands" {
  description = "Additional commands to run via cloud-config."
  type        = string
  default     = ""
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
  type        = list(string)
  default     = []
}

variable "extra_runcmd" {
  type        = list(string)
  default     = []
}

variable "extra_write_files" {
  type = list(object({
    path        = string
    permissions = string
    content     = string
  }))
  default = []
}

variable "override_template" {
  type        = string
  default     = null
  description = "If provided, replaces the entire cloud-init template"
}
