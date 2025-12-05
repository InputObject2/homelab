# This file contains the Xen orchestra configuration for VM's.
# docs : https://github.com/terra-farm/terraform-provider-xenorchestra/blob/master/docs/resources/vm.md
terraform {
  required_providers {
    macaddress = {
      source  = "ivoronin/macaddress"
      version = ">=0.3.0"
    }
  }

  required_version = ">= 1.0"
}