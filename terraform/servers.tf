# Nomad/Consul Server instances (3 servers total)
resource "google_compute_instance" "nomad_servers" {
  count        = 3
  name         = "nomad-server-${count.index + 1}"
  machine_type = var.machine_type_server
  zone         = var.zone

  tags = ["hashistack", "nomad-server", "consul-server", var.cluster_name]

  boot_disk {
    initialize_params {
      image = var.use_hcp_packer ? data.hcp_packer_artifact.hashistack_server[0].external_identifier : "debian-cloud/debian-12"
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
    ssh-keys = "debian:${var.ssh_public_key}"
    startup-script = templatefile("${path.module}/template.tpl", {
      dc_name = var.consul_datacenter,
      gcp_project = var.project_id,
      tag = var.cluster_name,
      consul_license = var.consul_license,
      nomad_license = var.nomad_license,
      bootstrap_token = random_uuid.consul_master_token.result,
      consul_encrypt_key = random_id.consul_encrypt.b64_std,
      zone = var.region,
      node_name = "server-${count.index}",
      nomad_token = random_uuid.nomad_server_token.result,
      nomad_bootstrapper = count.index == 2 ? true : false,
      consul_ca_cert = tls_self_signed_cert.ca.cert_pem,
      consul_ca_key = tls_private_key.ca.private_key_pem
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