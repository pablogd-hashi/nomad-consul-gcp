# Nomad/Consul Server instances (3 servers total)
resource "google_compute_instance" "nomad_servers" {
  count        = 3
  name         = "nomad-server-${count.index + 1}"
  machine_type = var.machine_type_server
  zone         = var.zone

  tags = ["hashistack", "nomad-server", "consul-server"]

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2004-lts"
      size  = 50
      type  = "pd-standard"
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.hashistack_subnet.id
    access_config {
      # Ephemeral IP
    }
  }

  service_account {
    email  = google_service_account.hashistack_sa.email
    scopes = ["cloud-platform"]
  }

  metadata = {
    ssh-keys = "ubuntu:${var.ssh_public_key}"
    startup-script = <<-EOF
      #!/bin/bash
      set -e
      
      # Variables from Terraform
      CONSUL_VER="${var.consul_version}"
      NOMAD_VER="${var.nomad_version}"
      
      echo "Starting server setup with Consul $CONSUL_VER and Nomad $NOMAD_VER"
      
      # Update system
      apt-get update
      apt-get install -y unzip curl jq
      
      # Create directories  
      mkdir -p /opt/consul/bin /opt/nomad/bin
      
      # Download Consul
      cd /tmp
      wget "https://releases.hashicorp.com/consul/$CONSUL_VER/consul_${CONSUL_VER}_linux_amd64.zip"
      unzip "consul_${CONSUL_VER}_linux_amd64.zip"
      mv consul /opt/consul/bin/
      chmod +x /opt/consul/bin/consul
      
      # Download Nomad  
      wget "https://releases.hashicorp.com/nomad/$NOMAD_VER/nomad_${NOMAD_VER}_linux_amd64.zip"
      unzip "nomad_${NOMAD_VER}_linux_amd64.zip"
      mv nomad /opt/nomad/bin/
      chmod +x /opt/nomad/bin/nomad
      
      echo "Basic setup complete"
    EOF
  }

  depends_on = [
    google_compute_subnetwork.hashistack_subnet
  ]
}

# Data source to get server private IPs for client configuration
data "google_compute_instance" "nomad_servers" {
  count = 3
  name  = google_compute_instance.nomad_servers[count.index].name
  zone  = var.zone
  
  depends_on = [google_compute_instance.nomad_servers]
}