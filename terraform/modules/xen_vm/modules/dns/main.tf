resource "dns_a_record_set" "this" {
  name = var.hostname
  zone = "${var.dns_domain_name}."

  ttl = var.ttl

  addresses = [
    var.ip_address
  ]
}

locals {
  octets        = split(".", var.ip_address)
  reversed      = reverse(local.octets)
  zone_elements = slice(local.reversed, 1, length(local.reversed))
}

resource "dns_ptr_record" "this" {
  name = local.reversed[0] # last octet
  zone = "${join(".", local.zone_elements)}.in-addr.arpa."
  ttl  = var.ttl
  ptr  = "${var.hostname}.${var.dns_domain_name}."
}
