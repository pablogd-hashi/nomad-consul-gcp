packer {
  required_plugins {
    googlecompute = {
      source  = "github.com/hashicorp/googlecompute"
      version = ">= 1.0.0"
    }
  }
}

variable "consul_version" {
  type        = string
  description = "Consul version to install"
  default     = "1.17.0+ent"
}

variable "nomad_version" {
  type        = string
  description = "Nomad version to install"
  default     = "1.7.2+ent"
}

variable "gcp_project" {
  type        = string
  description = "GCP Project ID"
}

variable "gcp_zone" {
  type        = string
  description = "GCP Zone"
  default     = "us-central1-a"
}

locals {
  timestamp = regex_replace(timestamp(), "[- TZ:]", "")
}

source "googlecompute" "consul-nomad" {
  project_id          = var.gcp_project
  source_image_family = "debian-12"
  source_image_project_id = ["debian-cloud"]
  zone                = var.gcp_zone
  machine_type        = "e2-standard-2"
  
  image_name          = "consul-nomad-server-${local.timestamp}"
  image_family        = "consul-nomad-server"
  image_description   = "Consul ${var.consul_version} and Nomad ${var.nomad_version} Server"
  
  disk_size           = 50
  disk_type          = "pd-standard"
  
  ssh_username       = "debian"
  
  tags = ["packer", "consul-nomad-server"]
}

build {
  name = "consul-nomad-server"
  sources = ["source.googlecompute.consul-nomad"]

  # Install Consul
  provisioner "shell" {
    environment_vars = [
      "CONSUL_VERSION=${var.consul_version}"
    ]
    script = "../scripts/consul_prep.sh"
  }

  # Install Nomad
  provisioner "shell" {
    environment_vars = [
      "NOMAD_VERSION=${var.nomad_version}"
    ]
    script = "../scripts/nomad_prep.sh"
  }

  post-processor "manifest" {
    output = "../manifest-server.json"
    strip_path = true
    custom_data = {
      consul_version = var.consul_version
      nomad_version  = var.nomad_version
    }
  }
}