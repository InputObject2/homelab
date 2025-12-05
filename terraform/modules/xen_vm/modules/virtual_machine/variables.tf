variable "hostname" {
  description = "The hostname to set in the cloud-config."
  type        = string
}

variable "hostname_description" {
  description = "Description for the VM hostname."
  type        = string
  default     = ""
}

variable "cloud_config" {
  description = "The cloud-config to use for the VM."
  type        = string
}

variable "cloud_network_config" {
  description = "The cloud network config to use for the VM."
  type        = string
}

variable "cpu_count" {
  description = "Number of CPUs for the VM."
  type        = number
}

variable "memory_gb" {
  description = "Memory in GB for the VM."
  type        = number
}

variable "disk_size" {
  description = "OS disk size in GB for the VM."
  type        = number
}

variable "xo_template_uuid" {
  description = "Template UUID for the VM in Xen Orchestra."
  type        = string
}

variable "xo_sr_id" {
  description = "Storage repository ID for VM OS disk."
  type        = string
}

variable "xo_network_id" {
  description = "Network ID for the VM in Xen Orchestra."
  type        = string
}

variable "mac_address" {
  description = "MAC address for the VM network interface."
  type        = string
}

variable "expected_cidr" {
  description = "Expected IP CIDR for the VM."
  type        = string
}

variable "auto_poweron" {
  description = "Whether to automatically power on the VM after creation."
  type        = bool
  default     = true
}

variable "start_delay" {
  description = "Delay in seconds before starting the VM."
  type        = number
  default     = 0
}

variable "tags" {
  description = "Tags to apply to the VM."
  type        = list(string)
  default     = []
}
