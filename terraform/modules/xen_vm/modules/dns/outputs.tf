output "name" {
  value = dns_a_record_set.this.name
}

output "zone" {
  value = dns_a_record_set.this.zone
}

output "addresses" {
  value = dns_a_record_set.this.addresses
}

output "ptr_name" {
  value = dns_ptr_record.this.name
}

output "ptr_zone" {
  value = dns_ptr_record.this.zone
}

output "ptr" {
  value = dns_ptr_record.this.ptr
}
