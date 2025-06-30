data "hcp_packer_artifact" "hashistack_server" {
  count               = var.use_hcp_packer ? 1 : 0
  bucket_name         = "hashistack-server"
  #version_fingerprint = data.hcp_packer_version.hashistack_server[0].fingerprint
  platform            = "gce"
  region              = var.region
  channel_name        = var.packer_image_channel

}


data "hcp_packer_artifact" "hashistack_client" {
  count               = var.use_hcp_packer ? 1 : 0
  bucket_name         = "hashistack-client" 
 # version_fingerprint = data.hcp_packer_version.hashistack_client[0].fingerprint
  platform            = "gce"
  channel_name = var.packer_image_channel
  region              = var.region
}