# Packer build variables
# Update with your actual GCP project ID

# GCP Project ID where images will be built
gcp_project = "hc-a7228bee27814bf1b3768e63f61"

# GCP zone for build
gcp_zone = "us-central1-a"

# HashiCorp software versions (matching working reference)
consul_version = "1.21.2+ent"
nomad_version  = "1.10.2+ent"