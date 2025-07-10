terraform {
  required_version = ">= 1.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 4.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.0"
    }
  }
}

# Configure the Google Cloud Provider
provider "google" {
  project = var.project_id
  region  = local.region
}

locals {
  cluster_name = "consul-server-west"
  region       = "us-west1"
  zones        = ["us-west1-a", "us-west1-b", "us-west1-c"]
}

# GKE Cluster for Consul Servers
resource "google_container_cluster" "consul_servers" {
  name     = local.cluster_name
  location = local.region

  # We can't create a cluster with no node pool defined, but we want to only use
  # separately managed node pools. So we create the smallest possible default
  # node pool and immediately delete it.
  remove_default_node_pool = true
  initial_node_count       = 1

  # Network configuration
  network    = "default"
  subnetwork = "default"

  # Enable workload identity
  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  # Enable admin partitions features
  addons_config {
    network_policy_config {
      disabled = false
    }
  }

  network_policy {
    enabled = true
  }

  # Master authorized networks - allow all for demo
  master_authorized_networks_config {
    cidr_blocks {
      cidr_block   = "0.0.0.0/0"
      display_name = "All"
    }
  }

  # Maintenance window
  maintenance_policy {
    daily_maintenance_window {
      start_time = "03:00"
    }
  }

  lifecycle {
    ignore_changes = [
      initial_node_count,
    ]
  }
}

# Consul server node pool
resource "google_container_node_pool" "consul_servers" {
  name       = "consul-servers"
  location   = local.region
  cluster    = google_container_cluster.consul_servers.name
  node_count = 1

  # Auto-scaling
  autoscaling {
    min_node_count = 1
    max_node_count = 3
  }

  # Node configuration
  node_config {
    preemptible  = true
    machine_type = "e2-standard-2"
    disk_size_gb = 20
    disk_type    = "pd-standard"

    # Google recommends custom service accounts that have cloud-platform scope and permissions granted via IAM Roles.
    service_account = var.service_account_email
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]

    # Workload Identity
    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    labels = {
      environment = "demo"
      component   = "consul-server"
      region      = local.region
    }

    tags = ["consul-server", "gke-node"]
  }

  # Node management
  management {
    auto_repair  = true
    auto_upgrade = true
  }

  # Update strategy
  upgrade_settings {
    max_surge       = 1
    max_unavailable = 0
  }
}

# Get cluster credentials
data "google_client_config" "default" {}

data "google_container_cluster" "consul_servers" {
  name     = google_container_cluster.consul_servers.name
  location = google_container_cluster.consul_servers.location
}

# Kubernetes provider configuration
provider "kubernetes" {
  host                   = "https://${data.google_container_cluster.consul_servers.endpoint}"
  token                  = data.google_client_config.default.access_token
  cluster_ca_certificate = base64decode(data.google_container_cluster.consul_servers.master_auth.0.cluster_ca_certificate)
}

# Helm provider configuration
provider "helm" {
  kubernetes {
    host                   = "https://${data.google_container_cluster.consul_servers.endpoint}"
    token                  = data.google_client_config.default.access_token
    cluster_ca_certificate = base64decode(data.google_container_cluster.consul_servers.master_auth.0.cluster_ca_certificate)
  }
}

# Create consul namespace
resource "kubernetes_namespace" "consul" {
  metadata {
    name = "consul"
    labels = {
      name = "consul"
    }
  }
  depends_on = [google_container_node_pool.consul_servers]
}

# Consul Enterprise license secret
resource "kubernetes_secret" "consul_license" {
  metadata {
    name      = "consul-enterprise-license"
    namespace = kubernetes_namespace.consul.metadata[0].name
  }

  data = {
    key = var.consul_license
  }

  type = "Opaque"
}

# Consul gossip encryption key
resource "kubernetes_secret" "consul_gossip_key" {
  metadata {
    name      = "consul-gossip-encryption-key"
    namespace = kubernetes_namespace.consul.metadata[0].name
  }

  data = {
    key = base64encode(random_id.gossip_key.b64_std)
  }

  type = "Opaque"
}

resource "random_id" "gossip_key" {
  byte_length = 32
}

# Consul TLS CA
resource "kubernetes_secret" "consul_ca" {
  metadata {
    name      = "consul-ca-cert"
    namespace = kubernetes_namespace.consul.metadata[0].name
  }

  data = {
    "tls.crt" = tls_self_signed_cert.consul_ca.cert_pem
    "tls.key" = tls_private_key.consul_ca.private_key_pem
  }

  type = "kubernetes.io/tls"
}

# Generate TLS CA for Consul
resource "tls_private_key" "consul_ca" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_self_signed_cert" "consul_ca" {
  private_key_pem = tls_private_key.consul_ca.private_key_pem

  subject {
    common_name  = "consul-ca"
    organization = "HashiCorp"
  }

  validity_period_hours = 8760 # 1 year

  is_ca_certificate = true

  allowed_uses = [
    "cert_signing",
    "key_encipherment",
    "digital_signature",
  ]
}

# Deploy Consul via Helm
resource "helm_release" "consul" {
  name       = "consul"
  repository = "https://helm.releases.hashicorp.com"
  chart      = "consul"
  version    = "1.5.0"
  namespace  = kubernetes_namespace.consul.metadata[0].name

  values = [
    templatefile("${path.module}/../../helm/server-west/values.yaml", {
      consul_version = var.consul_version
      datacenter     = "west"
      gossip_key     = base64encode(random_id.gossip_key.b64_std)
    })
  ]

  depends_on = [
    kubernetes_secret.consul_license,
    kubernetes_secret.consul_gossip_key,
    kubernetes_secret.consul_ca,
  ]
}

# Service to expose Consul UI
resource "kubernetes_service" "consul_ui" {
  metadata {
    name      = "consul-ui"
    namespace = kubernetes_namespace.consul.metadata[0].name
    labels = {
      app = "consul"
    }
  }

  spec {
    type = "LoadBalancer"
    
    port {
      port        = 8500
      target_port = 8500
      protocol    = "TCP"
    }

    selector = {
      app       = "consul"
      component = "server"
    }
  }

  depends_on = [helm_release.consul]
}