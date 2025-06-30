# HCP Packer data sources for getting the latest built images from HCP registry
data "hcp_packer_version" "hashistack_server" {
  bucket_name  = "hashistack-server"
  channel_name = var.packer_image_channel
}

data "hcp_packer_artifact" "hashistack_server" {
  bucket_name    = "hashistack-server"
  version_fingerprint = data.hcp_packer_version.hashistack_server.fingerprint
  platform       = "gce"
  region         = var.region
}

data "hcp_packer_version" "hashistack_client" {
  bucket_name  = "hashistack-client"
  channel_name = var.packer_image_channel
}

data "hcp_packer_artifact" "hashistack_client" {
  bucket_name    = "hashistack-client" 
  version_fingerprint = data.hcp_packer_version.hashistack_client.fingerprint
  platform       = "gce"
  region         = var.region
}