# docs : https://github.com/terra-farm/terraform-provider-xenorchestra/blob/master/docs/resources/vm.md
data "xenorchestra_pool" "this" {
  name_label = var.xo_pool_name
}

data "xenorchestra_network" "this" {
  pool_id    = data.xenorchestra_pool.this.id
  name_label = var.xo_network_name
}
