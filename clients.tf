# Nomad Client instances (2 clients)
resource "google_compute_instance" "nomad_clients" {
  count        = 2
  name         = "nomad-client-${count.index + 1}"
  machine_type = var.machine_type_client
  zone         = var.zone

  tags = ["hashistack", "nomad-client"]

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2004-lts"
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
    email  = google_service_account.hashistack_sa.email
    scopes = ["cloud-platform"]
  }

  metadata = {
    ssh-keys = "ubuntu:${var.ssh_public_key}"
    startup-script = templatefile("${path.module}/scripts/client-startup.sh", {
      consul_version      = var.consul_version
      nomad_version       = var.nomad_version
      consul_datacenter   = var.consul_datacenter
      nomad_datacenter    = var.nomad_datacenter
      consul_encrypt_key  = base64encode(random_id.consul_encrypt.hex)
      consul_master_token = random_uuid.consul_master_token.result
      nomad_client_token  = random_uuid.nomad_client_token.result
      consul_license      = var.consul_license
      nomad_license       = var.nomad_license
      client_index        = count.index + 1
      ca_cert             = base64encode(tls_self_signed_cert.ca.cert_pem)
      server_ips = join(",", [
        for instance in data.google_compute_instance.nomad_servers : instance.network_interface[0].network_ip
      ])
      subnet_cidr      = var.subnet_cidr
      enable_acls      = var.enable_acls
      enable_tls       = var.enable_tls
      consul_log_level = var.consul_log_level
      nomad_log_level  = var.nomad_log_level
      project_id       = var.project_id
    })
  }

  depends_on = [
    google_compute_subnetwork.hashistack_subnet,
    google_compute_instance.nomad_servers
  ]
}