variable "hostname" {
  description = "The hostname to set for the DNS records."
  type        = string
}
variable "dns_domain_name" {
  description = "The DNS domain name for the VM."
  type        = string
}
variable "ip_address" {
  description = "The IP address to assign to the DNS A record and PTR record."
  type        = string
}
variable "ttl" {
  description = "The TTL for the DNS records."
  type        = number
  default     = 300
}