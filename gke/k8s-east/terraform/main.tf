variable "gcp_project" {
  description = "GCP Project ID"
  type        = string
}

variable "gcp_region" {
  description = "GCP Region"
  type        = string
  default     = "europe-southwest1"
}

variable "cluster_name" {
  description = "GKE Cluster Name"
  type        = string
  default     = "k8s-east"
}

variable "node_count" {
  description = "Number of GKE nodes"
  type        = number
  default     = 3
}

variable "machine_type" {
  description = "GKE node machine type"
  type        = string
  default     = "e2-standard-4"
}

variable "consul_servers" {
  description = "List of Consul server IPs"
  type        = list(string)
  default     = []
}

variable "authorized_networks" {
  description = "Additional authorized networks for GKE master access"
  type        = list(string)
  default     = ["0.0.0.0/0"]  # Open to all IPs (development only)
}

# GKE Cluster
resource "google_container_cluster" "k8s_east" {
  name     = var.cluster_name
  location = var.gcp_region

  # Remove default node pool
  remove_default_node_pool = true
  initial_node_count       = 1

  # Network configuration
  network    = "default"
  subnetwork = "default"

  # Workload Identity
  workload_identity_config {
    workload_pool = "${var.gcp_project}.svc.id.goog"
  }

  # Addons
  addons_config {
    horizontal_pod_autoscaling {
      disabled = false
    }
    http_load_balancing {
      disabled = false
    }
    network_policy_config {
      disabled = false
    }
  }

  # Network policy
  network_policy {
    enabled  = true
    provider = "CALICO"
  }

  # Private cluster config
  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = false
    master_ipv4_cidr_block  = "10.0.0.0/28"
  }

  # IP allocation policy
  ip_allocation_policy {}

  # Master authorized networks (allow access from Consul servers and authorized networks)
  master_authorized_networks_config {
    dynamic "cidr_blocks" {
      for_each = var.consul_servers
      content {
        cidr_block   = "${cidr_blocks.value}/32"
        display_name = "consul-server-${cidr_blocks.key}"
      }
    }
    dynamic "cidr_blocks" {
      for_each = var.authorized_networks
      content {
        cidr_block   = cidr_blocks.value
        display_name = "authorized-network-${cidr_blocks.key}"
      }
    }
  }
}

# Node pool
resource "google_container_node_pool" "k8s_east_nodes" {
  name       = "${var.cluster_name}-nodes"
  location   = var.gcp_region
  cluster    = google_container_cluster.k8s_east.name
  node_count = var.node_count

  node_config {
    machine_type = var.machine_type
    disk_size_gb = 100
    disk_type    = "pd-standard"

    # Workload Identity
    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    # OAuth scopes
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]

    # Labels
    labels = {
      cluster     = var.cluster_name
      environment = "consul-admin-partition"
    }

    # Tags
    tags = ["consul-k8s", var.cluster_name]
  }

  # Autoscaling
  autoscaling {
    min_node_count = 1
    max_node_count = 5
  }

  # Management
  management {
    auto_repair  = true
    auto_upgrade = true
  }
}

# Outputs
output "cluster_name" {
  description = "GKE cluster name"
  value       = google_container_cluster.k8s_east.name
}

output "cluster_endpoint" {
  description = "GKE cluster endpoint"
  value       = google_container_cluster.k8s_east.endpoint
}

output "cluster_ca_certificate" {
  description = "GKE cluster CA certificate"
  value       = google_container_cluster.k8s_east.master_auth[0].cluster_ca_certificate
}

output "get_credentials_command" {
  description = "Command to get cluster credentials"
  value       = "gcloud container clusters get-credentials ${google_container_cluster.k8s_east.name} --region ${var.gcp_region} --project ${var.gcp_project}"
}

output "kubectl_config_context" {
  description = "kubectl context name"
  value       = "gke_${var.gcp_project}_${var.gcp_region}_${google_container_cluster.k8s_east.name}"
}