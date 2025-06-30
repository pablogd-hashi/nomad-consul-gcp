# Nomad Client instances (2 clients)
resource "google_compute_instance" "nomad_clients" {
  count        = 2
  name         = "nomad-client-${count.index + 1}"
  machine_type = var.machine_type_client
  zone         = var.zone

  tags = ["hashistack", "nomad-client"]

  boot_disk {
    initialize_params {
      image = data.hcp_packer_artifact.hashistack_client.external_identifier
      size  = 100
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
    email  = var.gcp_sa
    scopes = ["cloud-platform"]
  }

  metadata = {
    ssh-keys = "ubuntu:${var.ssh_public_key}"
    startup-script = <<-EOF
      #!/bin/bash
      set -e
      
      # Set environment variables for the configuration script
      export CONSUL_DATACENTER="${var.consul_datacenter}"
      export NOMAD_DATACENTER="${var.nomad_datacenter}"
      export CONSUL_TOKEN="${random_uuid.nomad_client_token.result}"
      export CONSUL_ENCRYPT_KEY="${base64encode(random_string.consul_encrypt_key.result)}"
      export NOMAD_ENCRYPT_KEY="${base64encode(random_string.nomad_encrypt_key.result)}"
      export CONSUL_LICENSE="${var.consul_license}"
      export NOMAD_LICENSE="${var.nomad_license}"
      export PROJECT_ID="${var.project_id}"
      export CONSUL_LOG_LEVEL="${var.consul_log_level}"
      export NOMAD_LOG_LEVEL="${var.nomad_log_level}"
      export ENABLE_ACLS="${var.enable_acls}"
      
      # Run the configuration script from the Packer image
      /opt/hashistack/scripts/configure-client.sh
    EOF
  }

  depends_on = [
    google_compute_subnetwork.hashistack_subnet,
    google_compute_instance.nomad_servers
  ]
}