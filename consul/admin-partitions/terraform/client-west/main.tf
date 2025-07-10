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
  cluster_name     = "consul-client-west"
  region           = "us-west2"
  partition_name   = "k8s-west"
  consul_server_ip = var.consul_server_ip
}

# GKE Cluster for Admin Partition Client
resource "google_container_cluster" "consul_client" {
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

# Client node pool
resource "google_container_node_pool" "consul_clients" {
  name       = "consul-clients"
  location   = local.region
  cluster    = google_container_cluster.consul_client.name
  node_count = 1

  # Auto-scaling
  autoscaling {
    min_node_count = 1
    max_node_count = 5
  }

  # Node configuration
  node_config {
    preemptible  = true
    machine_type = "e2-standard-4"
    disk_size_gb = 30
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
      component   = "consul-client"
      partition   = local.partition_name
      region      = local.region
    }

    tags = ["consul-client", "gke-node", local.partition_name]
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

  lifecycle {
    ignore_changes = [
      node_config,
      initial_node_count,
    ]
  }
}

# Get cluster credentials
data "google_client_config" "default" {}

data "google_container_cluster" "consul_client" {
  name     = google_container_cluster.consul_client.name
  location = google_container_cluster.consul_client.location
}

# Kubernetes provider configuration
provider "kubernetes" {
  host                   = "https://${data.google_container_cluster.consul_client.endpoint}"
  token                  = data.google_client_config.default.access_token
  cluster_ca_certificate = base64decode(data.google_container_cluster.consul_client.master_auth.0.cluster_ca_certificate)
}

# Helm provider configuration
provider "helm" {
  kubernetes {
    host                   = "https://${data.google_container_cluster.consul_client.endpoint}"
    token                  = data.google_client_config.default.access_token
    cluster_ca_certificate = base64decode(data.google_container_cluster.consul_client.master_auth.0.cluster_ca_certificate)
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
  depends_on = [google_container_node_pool.consul_clients]
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

# Consul CA certificate (from servers)
resource "kubernetes_secret" "consul_ca" {
  metadata {
    name      = "consul-ca-cert"
    namespace = kubernetes_namespace.consul.metadata[0].name
  }

  data = {
    "tls.crt" = var.consul_ca_cert
  }

  type = "Opaque"
}

# Bootstrap token for admin partition
resource "kubernetes_secret" "consul_bootstrap_token" {
  metadata {
    name      = "consul-partitions-acl-token"
    namespace = kubernetes_namespace.consul.metadata[0].name
  }

  data = {
    token = var.consul_bootstrap_token
  }

  type = "Opaque"
}

# Deploy Consul via Helm (Admin Partition Client)
resource "helm_release" "consul" {
  name       = "consul"
  repository = "https://helm.releases.hashicorp.com"
  chart      = "consul"
  version    = "1.5.0"
  namespace  = kubernetes_namespace.consul.metadata[0].name

  values = [
    templatefile("${path.module}/../../helm/client-west/values.yaml", {
      consul_version      = var.consul_version
      partition_name      = local.partition_name
      consul_server_ip    = local.consul_server_ip
      k8s_api_endpoint    = data.google_container_cluster.consul_client.endpoint
    })
  ]

  depends_on = [
    kubernetes_secret.consul_license,
    kubernetes_secret.consul_ca,
    kubernetes_secret.consul_bootstrap_token,
  ]
}

# DTAP Namespaces
resource "kubernetes_namespace" "development" {
  metadata {
    name = "development"
    labels = {
      environment = "development"
      partition   = local.partition_name
    }
    annotations = {
      "consul.hashicorp.com/connect-inject" = "true"
    }
  }
  depends_on = [helm_release.consul]
}

resource "kubernetes_namespace" "testing" {
  metadata {
    name = "testing"
    labels = {
      environment = "testing"
      partition   = local.partition_name
    }
    annotations = {
      "consul.hashicorp.com/connect-inject" = "true"
    }
  }
  depends_on = [helm_release.consul]
}

resource "kubernetes_namespace" "acceptance" {
  metadata {
    name = "acceptance"
    labels = {
      environment = "acceptance"
      partition   = local.partition_name
    }
    annotations = {
      "consul.hashicorp.com/connect-inject" = "true"
    }
  }
  depends_on = [helm_release.consul]
}

resource "kubernetes_namespace" "production" {
  metadata {
    name = "production"
    labels = {
      environment = "production"
      partition   = local.partition_name
    }
    annotations = {
      "consul.hashicorp.com/connect-inject" = "true"
    }
  }
  depends_on = [helm_release.consul]
}