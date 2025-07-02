# 🌐 CONSUL UI
output "consul_ui" {
  description = "Consul Web UI"
  value       = "http://${google_compute_instance.nomad_servers[0].network_interface[0].access_config[0].nat_ip}:8500"
}

# 🚀 NOMAD UI  
output "nomad_ui" {
  description = "Nomad Web UI"
  value       = "http://${google_compute_instance.nomad_servers[0].network_interface[0].access_config[0].nat_ip}:4646"
}

# 🔑 CONSUL TOKEN
output "consul_token" {
  description = "Consul Master Token (copy this for UI login)"
  value       = random_uuid.consul_master_token.result
  sensitive   = true
}

# 🔑 NOMAD TOKEN
output "nomad_token" {
  description = "Nomad Server Token (copy this for UI login)" 
  value       = random_uuid.nomad_server_token.result
  sensitive   = true
}

# 🖥️ SERVER IPs
output "server_ips" {
  description = "All Nomad/Consul server IP addresses"
  value = {
    for i, server in google_compute_instance.nomad_servers :
    "server-${i + 1}" => {
      public_ip  = server.network_interface[0].access_config[0].nat_ip
      private_ip = server.network_interface[0].network_ip
      ssh_command = "ssh debian@${server.network_interface[0].access_config[0].nat_ip}"
    }
  }
}

# 🖥️ CLIENT IPs  
output "client_ips" {
  description = "All Nomad client IP addresses"
  value = {
    for i, client in google_compute_instance.nomad_clients :
    "client-${i + 1}" => {
      public_ip  = client.network_interface[0].access_config[0].nat_ip
      private_ip = client.network_interface[0].network_ip
      ssh_command = "ssh debian@${client.network_interface[0].access_config[0].nat_ip}"
    }
  }
}

# Legacy output names for backward compatibility
output "consul_servers" {
  description = "Consul server IPs (legacy name)"
  value = {
    for i, server in google_compute_instance.nomad_servers :
    "server-${i + 1}" => {
      public_ip  = server.network_interface[0].access_config[0].nat_ip
      private_ip = server.network_interface[0].network_ip
    }
  }
}

output "nomad_clients" {
  description = "Nomad client IPs (legacy name)" 
  value = {
    for i, client in google_compute_instance.nomad_clients :
    "client-${i + 1}" => {
      public_ip  = client.network_interface[0].access_config[0].nat_ip
      private_ip = client.network_interface[0].network_ip
    }
  }
}

# 🎯 APPS URL (IP-based)
output "apps_url" {
  description = "Application URLs (after deploying apps)"
  value = {
    traefik    = "http://${google_compute_instance.nomad_clients[0].network_interface[0].access_config[0].nat_ip}:8080"
    demo       = "http://${google_compute_instance.nomad_clients[0].network_interface[0].access_config[0].nat_ip}:8101"
    grafana    = "http://${google_compute_instance.nomad_clients[1].network_interface[0].access_config[0].nat_ip}:3000" 
    prometheus = "http://${google_compute_instance.nomad_clients[0].network_interface[0].access_config[0].nat_ip}:9090"
  }
}

# 🌐 DNS URLs (Much easier!)
output "dns_urls" {
  description = "DNS-based URLs for services (only if DNS zone is configured)"
  value = var.dns_zone_name != "" ? {
    grafana    = "http://${google_dns_record_set.grafana[0].name}:3000"
    prometheus = "http://${google_dns_record_set.prometheus[0].name}:9090"
    traefik    = "http://${google_dns_record_set.traefik[0].name}:8080"
    demo       = "http://${google_dns_record_set.demo[0].name}/frontend"
    consul     = "http://${google_dns_record_set.consul[0].name}:8500"
    nomad      = "http://${google_dns_record_set.nomad[0].name}:4646"
    terramino  = "http://${google_dns_record_set.terramino[0].name}"
  } : {}
}

# 📋 QUICK ACCESS COMMANDS
output "quick_access" {
  description = "Copy-paste commands to get tokens quickly"
  value = {
    consul_token_cmd = "terraform output -raw consul_token"
    nomad_token_cmd  = "terraform output -raw nomad_token"
    all_urls_cmd     = "terraform output"
    eval_vars_cmd    = "eval $(terraform output -raw eval_vars)"
  }
}

# 🔧 ENVIRONMENT VARIABLES
output "eval_vars" {
  description = "Run: eval $(terraform output -raw eval_vars) to set all environment variables"
  value = <<EOF
export CONSUL_HTTP_ADDR="http://${google_compute_instance.nomad_servers[0].network_interface[0].access_config[0].nat_ip}:8500"
export CONSUL_HTTP_TOKEN="${random_uuid.consul_master_token.result}"
export NOMAD_ADDR="http://${google_compute_instance.nomad_servers[0].network_interface[0].access_config[0].nat_ip}:4646"
export NOMAD_TOKEN="${random_uuid.nomad_server_token.result}"
EOF
}