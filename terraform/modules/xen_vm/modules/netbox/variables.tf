variable "hostname" {
  description = "Hostname of the virtual machine to register in NetBox."
  type        = string
}
variable "ip_address" {
  description = "Primary IP address of the virtual machine."
  type        = string
}
variable "mac_address" {
  description = "MAC address of the virtual machine's primary network interface."
  type        = string
}
variable "xo_cluster_name" {
  description = "Name of the XenOrchestra cluster/pool hosting this VM."
  type        = string
}
variable "xo_vm_uuid" {
  description = "UUID of the XenOrchestra VM resource."
  type        = string
}
variable "cloud_config" {
  description = "The cloud-init user-data config passed to the VM."
  type        = string
}
variable "network_config" {
  description = "The cloud-init network config passed to the VM."
  type        = string
}
