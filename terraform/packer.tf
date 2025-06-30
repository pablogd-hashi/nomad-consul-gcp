# HCP Packer artifact data sources
data "hcp_packer_artifact" "hashistack_server" {
  count        = var.use_hcp_packer ? 1 : 0
  bucket_name  = "consul-nomad-server"
  channel_name = "latest"
  platform     = "gce"
  region       = var.zone
}

data "hcp_packer_artifact" "hashistack_client" {
  count        = var.use_hcp_packer ? 1 : 0
  bucket_name  = "consul-nomad-client"
  channel_name = "latest"
  platform     = "gce"
  region       = var.zone
}