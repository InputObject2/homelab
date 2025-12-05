# This file contains the Xen orchestra configuration for VM's.
# docs : https://github.com/terra-farm/terraform-provider-xenorchestra/blob/master/docs/resources/vm.md
terraform {
  required_providers {
    dns = {
      source  = "hashicorp/dns"
      version = ">=3.4.3"
    }
  }

  required_version = ">= 1.0"
}