output "cluster_name" {
  description = "GKE cluster name"
  value       = google_container_cluster.consul_servers.name
}

output "cluster_endpoint" {
  description = "GKE cluster endpoint"
  value       = google_container_cluster.consul_servers.endpoint
  sensitive   = true
}

output "cluster_location" {
  description = "GKE cluster location"
  value       = google_container_cluster.consul_servers.location
}

output "consul_ui_ip" {
  description = "Consul UI Load Balancer IP"
  value       = try(data.kubernetes_service.consul_ui.status[0].load_balancer[0].ingress[0].ip, "pending")
}

output "consul_ui_url" {
  description = "Consul UI URL"
  value       = "http://${try(data.kubernetes_service.consul_ui.status[0].load_balancer[0].ingress[0].ip, "pending")}:8500"
}

output "consul_ca_cert" {
  description = "Consul CA certificate"
  value       = tls_self_signed_cert.consul_ca.cert_pem
  sensitive   = true
}

output "consul_ca_key" {
  description = "Consul CA private key"
  value       = tls_private_key.consul_ca.private_key_pem
  sensitive   = true
}

output "gossip_encryption_key" {
  description = "Consul gossip encryption key"
  value       = random_id.gossip_key.b64_std
  sensitive   = true
}

output "kubectl_config_command" {
  description = "Command to configure kubectl"
  value       = "gcloud container clusters get-credentials ${google_container_cluster.consul_servers.name} --region ${google_container_cluster.consul_servers.location} --project ${var.project_id}"
}