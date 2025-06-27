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
    startup-script = templatefile("${path.module}/scripts/server-startup.sh", {
      consul_version       = var.consul_version
      nomad_version        = var.nomad_version
      consul_datacenter    = var.consul_datacenter
      nomad_datacenter     = var.nomad_datacenter
      consul_encrypt_key   = base64encode(random_id.consul_encrypt.hex)
      consul_master_token  = random_uuid.consul_master_token.result
      nomad_consul_token   = random_uuid.nomad_consul_token.result
      nomad_server_token   = random_uuid.nomad_server_token.result
      nomad_client_token   = random_uuid.nomad_client_token.result
      consul_license       = var.consul_license
      nomad_license        = var.nomad_license
      server_index         = count.index + 1
      server_count         = 3
      ca_cert              = base64encode(tls_self_signed_cert.ca.cert_pem)
      ca_key               = base64encode(tls_private_key.ca.private_key_pem)
      subnet_cidr          = var.subnet_cidr
      enable_acls          = var.enable_acls
      enable_tls           = var.enable_tls
      consul_log_level     = var.consul_log_level
      nomad_log_level      = var.nomad_log_level
      project_id           = var.project_id
    })
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
