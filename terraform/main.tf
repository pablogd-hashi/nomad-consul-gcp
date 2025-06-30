provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}

provider "hcp" {
  # HCP provider configuration - uses HCP_CLIENT_ID and HCP_CLIENT_SECRET environment variables
}

# Generate random tokens for demo purposes
resource "random_uuid" "consul_master_token" {}

resource "random_uuid" "nomad_server_token" {}

resource "random_uuid" "nomad_client_token" {}

resource "random_uuid" "application_token" {}

resource "random_string" "consul_encrypt_key" {
  length  = 32
  special = false
}

resource "random_string" "nomad_encrypt_key" {
  length  = 32
  special = false
}

# Create VPC Network
resource "google_compute_network" "hashistack_vpc" {
  name                    = "hashistack-vpc"
  auto_create_subnetworks = false
  description             = "VPC for HashiCorp stack deployment"
}

# Create subnet
resource "google_compute_subnetwork" "hashistack_subnet" {
  name          = "hashistack-subnet"
  ip_cidr_range = var.subnet_cidr
  region        = var.region
  network       = google_compute_network.hashistack_vpc.id
  
  secondary_ip_range {
    range_name    = "pods"
    ip_cidr_range = "10.1.0.0/16"
  }
  
  secondary_ip_range {
    range_name    = "services"
    ip_cidr_range = "10.2.0.0/16"
  }
}

# Firewall rules
resource "google_compute_firewall" "allow_internal" {
  name    = "hashistack-allow-internal"
  network = google_compute_network.hashistack_vpc.name

  allow {
    protocol = "tcp"
  }

  allow {
    protocol = "udp"
  }

  allow {
    protocol = "icmp"
  }

  source_ranges = [var.subnet_cidr, "10.1.0.0/16", "10.2.0.0/16"]
}

resource "google_compute_firewall" "allow_ssh" {
  name    = "hashistack-allow-ssh"
  network = google_compute_network.hashistack_vpc.name

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["hashistack"]
}

resource "google_compute_firewall" "allow_http_https" {
  name    = "hashistack-allow-http-https"
  network = google_compute_network.hashistack_vpc.name

  allow {
    protocol = "tcp"
    ports    = ["80", "443", "8080", "8500", "4646", "3000", "9090"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["hashistack", "load-balancer"]
}

resource "google_compute_firewall" "allow_consul" {
  name    = "hashistack-allow-consul"
  network = google_compute_network.hashistack_vpc.name

  allow {
    protocol = "tcp"
    ports    = ["8300", "8301", "8302", "8500", "8600"]
  }

  allow {
    protocol = "udp"
    ports    = ["8301", "8302", "8600"]
  }

  source_ranges = [var.subnet_cidr]
  target_tags   = ["hashistack"]
}

resource "google_compute_firewall" "allow_nomad" {
  name    = "hashistack-allow-nomad"
  network = google_compute_network.hashistack_vpc.name

  allow {
    protocol = "tcp"
    ports    = ["4646", "4647", "4648"]
  }

  source_ranges = [var.subnet_cidr]
  target_tags   = ["hashistack"]
}

resource "google_compute_firewall" "allow_traefik" {
  name    = "hashistack-allow-traefik"
  network = google_compute_network.hashistack_vpc.name

  allow {
    protocol = "tcp"
    ports    = ["80", "443", "8080"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["hashistack"]
}

# Use existing service account instead of creating new one
data "google_service_account" "existing_sa" {
  account_id = var.gcp_sa
}
# Generate CA certificate for internal communication
resource "tls_private_key" "ca" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_self_signed_cert" "ca" {
  private_key_pem = tls_private_key.ca.private_key_pem

  subject {
    common_name  = "HashiStack CA"
    organization = "HashiStack Demo"
  }

  validity_period_hours = 8760 # 1 year

  is_ca_certificate = true

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "cert_signing",
  ]
}

# Generate Consul encryption key
resource "random_id" "consul_encrypt" {
  byte_length = 32
}

