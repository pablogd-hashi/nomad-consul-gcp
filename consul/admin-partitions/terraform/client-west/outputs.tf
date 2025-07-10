output "cluster_name" {
  description = "GKE cluster name"
  value       = google_container_cluster.consul_client.name
}

output "cluster_endpoint" {
  description = "GKE cluster endpoint"
  value       = google_container_cluster.consul_client.endpoint
  sensitive   = true
}

output "cluster_location" {
  description = "GKE cluster location"
  value       = google_container_cluster.consul_client.location
}

output "partition_name" {
  description = "Admin partition name"
  value       = local.partition_name
}

output "kubectl_config_command" {
  description = "Command to configure kubectl"
  value       = "gcloud container clusters get-credentials ${google_container_cluster.consul_client.name} --region ${google_container_cluster.consul_client.location} --project ${var.project_id}"
}

output "namespaces" {
  description = "DTAP namespaces created"
  value = [
    kubernetes_namespace.development.metadata[0].name,
    kubernetes_namespace.testing.metadata[0].name,
    kubernetes_namespace.acceptance.metadata[0].name,
    kubernetes_namespace.production.metadata[0].name,
  ]
}