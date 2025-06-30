# Example Packer build variables
# Copy this file to build.auto.pkrvars.hcl and customize for your environment

# GCP Project ID where images will be built
project_id = "hc-a7228bee27814bf1b3768e63f61"

# GCP region and zone for build
region = "us-central1"
zone   = "us-central1-a"

# HashiCorp software versions
consul_version = "1.20.0+ent"
nomad_version  = "1.10.0+ent"

# Image naming
image_name   = "hashistack-server"  # or "hashistack-client"
image_family = "hashistack-server"  # or "hashistack-client"