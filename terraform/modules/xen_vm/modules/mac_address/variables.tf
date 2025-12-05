variable "mac_prefix" {
  description = "The MAC address prefix to use for generated MAC addresses."
  type        = list(number)
  default     = [0, 22, 62]
}