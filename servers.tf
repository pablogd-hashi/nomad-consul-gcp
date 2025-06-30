# Nomad/Consul Server instances (3 servers total)
resource "google_compute_instance" "nomad_servers" {
  count        = 3
  name         = "nomad-server-${count.index + 1}"
  machine_type = var.machine_type_server
  zone         = var.zone

  tags = ["hashistack", "nomad-server", "consul-server"]

  boot_disk {
    initialize_params {
      image = data.hcp_packer_artifact.hashistack_server.external_identifier
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
      export CONSUL_MASTER_TOKEN="${random_uuid.consul_master_token.result}"
      export NOMAD_CONSUL_TOKEN="${random_uuid.nomad_server_token.result}"
      export NOMAD_SERVER_TOKEN="${random_uuid.nomad_server_token.result}"
      export CONSUL_ENCRYPT_KEY="${base64encode(random_string.consul_encrypt_key.result)}"
      export NOMAD_ENCRYPT_KEY="${base64encode(random_string.nomad_encrypt_key.result)}"
      export CONSUL_LICENSE="${var.consul_license}"
      export NOMAD_LICENSE="${var.nomad_license}"
      export SERVER_COUNT="3"
      export PROJECT_ID="${var.project_id}"
      export CONSUL_LOG_LEVEL="${var.consul_log_level}"
      export NOMAD_LOG_LEVEL="${var.nomad_log_level}"
      export ENABLE_ACLS="${var.enable_acls}"
      
      # Run the configuration script from the Packer image
      /opt/hashistack/scripts/configure-server.sh
      
      # Bootstrap ACLs on first server
      SERVER_IDX="${count.index + 1}"
      if [ "$SERVER_IDX" = "1" ] && [ "${var.enable_acls}" = "true" ]; then
        echo "Bootstrapping ACLs on server 1..."
        sleep 60
        export CONSUL_HTTP_TOKEN="${random_uuid.consul_master_token.result}"
        export NOMAD_TOKEN="${random_uuid.nomad_server_token.result}"
        nomad acl bootstrap -initial-management-token="${random_uuid.nomad_server_token.result}" || echo "ACL bootstrap failed or already done"
      fi
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