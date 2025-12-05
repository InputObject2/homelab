# This file contains the Xen orchestra configuration for VM's.
# docs : https://github.com/terra-farm/terraform-provider-xenorchestra/blob/master/docs/resources/vm.md
terraform {
  required_providers {
    netbox = {
      source  = "e-breuninger/netbox"
      version = ">=5.0.0"
    }
  }

  required_version = ">= 1.0"
}