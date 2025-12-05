# This file contains the Xen orchestra configuration for VM's.
# docs : https://github.com/terra-farm/terraform-provider-xenorchestra/blob/master/docs/resources/vm.md
terraform {
  required_providers {
    xenorchestra = {
      source  = "vatesfr/xenorchestra"
      version = "0.29.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">=3.6.3"
    }
    null = {
      source  = "hashicorp/null"
      version = ">=3.2.4"
    }
  }

  required_version = ">= 1.0"
}