# HCP Packer data sources for getting the latest built images from HCP registry
data "hcp_packer_iteration" "hashistack_server" {
  bucket_name = "hashistack-server"
  channel     = var.packer_image_channel
}

data "hcp_packer_image" "hashistack_server" {
  bucket_name      = "hashistack-server"
  iteration_id     = data.hcp_packer_iteration.hashistack_server.ulid
  cloud_provider   = "gce"
  region           = var.region
}

data "hcp_packer_iteration" "hashistack_client" {
  bucket_name = "hashistack-client"
  channel     = var.packer_image_channel
}

data "hcp_packer_image" "hashistack_client" {
  bucket_name      = "hashistack-client"
  iteration_id     = data.hcp_packer_iteration.hashistack_client.ulid
  cloud_provider   = "gce"
  region           = var.region
}