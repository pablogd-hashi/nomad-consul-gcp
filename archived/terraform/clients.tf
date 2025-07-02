# Nomad Client instances (2 clients)
resource "google_compute_instance" "nomad_clients" {
  count        = 2
  name         = "nomad-client-${count.index + 1}"
  machine_type = var.machine_type_client
  zone         = var.zone

  tags = ["hashistack", "nomad-client", var.cluster_name]

  boot_disk {
    initialize_params {
      image = var.use_hcp_packer ? data.hcp_packer_artifact.hashistack_client[0].external_identifier : "debian-cloud/debian-12"
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
    ssh-keys = "debian:${var.ssh_public_key}"
    startup-script = templatefile("${path.module}/template-client.tpl", {
      dc_name = var.consul_datacenter,
      gcp_project = var.project_id,
      tag = var.cluster_name,
      consul_license = var.consul_license,
      nomad_license = var.nomad_license,
      bootstrap_token = random_uuid.consul_master_token.result,
      consul_encrypt_key = random_id.consul_encrypt.b64_std,
      zone = var.region,
      node_name = "client-${count.index}",
      partition = "default",
      consul_ca_cert = tls_self_signed_cert.ca.cert_pem
    })
  }

  depends_on = [
    google_compute_subnetwork.hashistack_subnet,
    google_compute_instance.nomad_servers
  ]
}