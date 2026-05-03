output "name" {
  description = "The DNS A record name created for the VM."
  value       = dns_a_record_set.this.name
}

output "zone" {
  description = "The DNS zone in which the A record was created."
  value       = dns_a_record_set.this.zone
}

output "addresses" {
  description = "The IP addresses registered in the A record."
  value       = dns_a_record_set.this.addresses
}
output "ptr_name" {
  description = "The last octet used as the PTR record name."
  value       = dns_ptr_record.this.name
}

output "ptr_zone" {
  description = "The reverse DNS zone the PTR record was created in."
  value       = dns_ptr_record.this.zone
}

output "ptr" {
  description = "The PTR record value (FQDN the IP resolves to)."
  value       = dns_ptr_record.this.ptr
}
