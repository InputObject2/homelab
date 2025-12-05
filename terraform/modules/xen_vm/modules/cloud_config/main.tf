locals {
  render_default = templatefile("${path.module}/templates/cloud-init.yaml.tmpl", {
    hostname       = var.hostname
    username       = var.username
    public_ssh_key = var.public_ssh_key
    packages       = local.final_packages
    runcmd         = local.final_runcmd
    write_files    = local.final_write_files
  })

  cloud_config = var.override_template != null ? var.override_template : local.render_default
}

resource "xenorchestra_cloud_config" "this" {
  name     = var.hostname
  template = local.cloud_config
}
