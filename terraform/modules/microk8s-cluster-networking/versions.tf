terraform {
  required_version = ">= 1.0"

  required_providers {
    #routeros = {
    #  source = "terraform-routeros/routeros"
    #}
    netbox = {
      source  = "e-breuninger/netbox"
      version = ">=4.2.0"
    }
    #xenorchestra = {
    #  source = "vatesfr/xenorchestra"
    #}
    macaddress = {
      source  = "ivoronin/macaddress"
      version = ">=0.3.0"
    }
  }
}
