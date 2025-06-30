# HCP Packer data sources for getting the latest built images from HCP registry (optional)
data "hcp_packer_version" "hashistack_server" {
  count        = var.use_hcp_packer ? 1 : 0
  bucket_name  = "hashistack-server"
  channel_name = var.packer_image_channel
}

data "hcp_packer_artifact" "hashistack_server" {
  count               = var.use_hcp_packer ? 1 : 0
  bucket_name         = "hashistack-server"
  version_fingerprint = data.hcp_packer_version.hashistack_server[0].fingerprint
  platform            = "gce"
  region              = var.region
}

data "hcp_packer_version" "hashistack_client" {
  count        = var.use_hcp_packer ? 1 : 0
  bucket_name  = "hashistack-client"
  channel_name = var.packer_image_channel
}

data "hcp_packer_artifact" "hashistack_client" {
  count               = var.use_hcp_packer ? 1 : 0
  bucket_name         = "hashistack-client" 
  version_fingerprint = data.hcp_packer_version.hashistack_client[0].fingerprint
  platform            = "gce"
  region              = var.region
}