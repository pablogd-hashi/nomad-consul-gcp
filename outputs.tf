output "load_balancer_ip" {
  description = "IP address of the load balancer"
  value       = google_compute_global_address.hashistack_lb_ip.address
}

output "consul_servers" {
  description = "Consul server instances"
  value = {
    for i, instance in google_compute_instance.nomad_servers : 
    "server-${i + 1}" => {
      name       = instance.name
      private_ip = instance.network_interface[0].network_ip
      public_ip  = instance.network_interface[0].access_config[0].nat_ip
    }
  }
}

output "nomad_clients" {
  description = "Nomad client instances"
  value = {
    for i, instance in google_compute_instance.nomad_clients : 
    "client-${i + 1}" => {
      name       = instance.name
      private_ip = instance.network_interface[0].network_ip
      public_ip  = instance.network_interface[0].access_config[0].nat_ip
    }
  }
}

output "consul_ui_urls" {
  description = "Consul UI URLs"
  value = [
    for instance in google_compute_instance.nomad_servers : 
    "http://${instance.network_interface[0].access_config[0].nat_ip}:8500"
  ]
}

output "nomad_ui_urls" {
  description = "Nomad UI URLs"
  value = [
    for instance in google_compute_instance.nomad_servers : 
    "http://${instance.network_interface[0].access_config[0].nat_ip}:4646"
  ]
}

output "consul_master_token" {
  description = "Consul master token for ACL access"
  value       = random_uuid.consul_master_token.result
  sensitive   = true
}

output "nomad_server_token" {
  description = "Nomad server token for ACL access"
  value       = random_uuid.nomad_server_token.result
  sensitive   = true
}

output "application_urls" {
  description = "Application URLs via load balancer"
  value = var.dns_zone != "" ? {
    terramino  = "http://terramino-${var.cluster_name}.${data.google_dns_managed_zone.doormat_dns_zone[0].dns_name}"
    grafana    = "http://grafana-${var.cluster_name}.${data.google_dns_managed_zone.doormat_dns_zone[0].dns_name}"
    prometheus = "http://prometheus-${var.cluster_name}.${data.google_dns_managed_zone.doormat_dns_zone[0].dns_name}"
  } : {
    terramino  = "http://${google_compute_global_address.hashistack_lb_ip.address} (Host: terramino-${var.cluster_name}.${var.domain_name})"
    grafana    = "http://${google_compute_global_address.hashistack_lb_ip.address} (Host: grafana-${var.cluster_name}.${var.domain_name})"
    prometheus = "http://${google_compute_global_address.hashistack_lb_ip.address} (Host: prometheus-${var.cluster_name}.${var.domain_name})"
  }
}

output "ssh_commands" {
  description = "SSH commands to connect to instances"
  value = {
    servers = [
      for instance in google_compute_instance.nomad_servers :
      "ssh ubuntu@${instance.network_interface[0].access_config[0].nat_ip}"
    ]
    clients = [
      for instance in google_compute_instance.nomad_clients :
      "ssh ubuntu@${instance.network_interface[0].access_config[0].nat_ip}"
    ]
  }
}

output "dns_configuration" {
  description = "DNS configuration needed for domain routing"
  value = {
    load_balancer_ip = google_compute_global_address.hashistack_lb_ip.address
    required_dns_records = var.dns_zone != "" ? [
      "terramino-${var.cluster_name}.${data.google_dns_managed_zone.doormat_dns_zone[0].dns_name} -> ${google_compute_global_address.hashistack_lb_ip.address}",
      "grafana-${var.cluster_name}.${data.google_dns_managed_zone.doormat_dns_zone[0].dns_name} -> ${google_compute_global_address.hashistack_lb_ip.address}",
      "prometheus-${var.cluster_name}.${data.google_dns_managed_zone.doormat_dns_zone[0].dns_name} -> ${google_compute_global_address.hashistack_lb_ip.address}"
    ] : [
      "Use /etc/hosts or DNS to point these to ${google_compute_global_address.hashistack_lb_ip.address}:",
      "terramino-${var.cluster_name}.${var.domain_name}",
      "grafana-${var.cluster_name}.${var.domain_name}",
      "prometheus-${var.cluster_name}.${var.domain_name}"
    ]
  }
}
