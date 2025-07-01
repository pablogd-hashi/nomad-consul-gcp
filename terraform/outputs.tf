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

# 🎯 APPS URL (when deployed)
output "apps_url" {
  description = "Application URLs (after deploying apps)"
  value = {
    terramino  = "http://${google_compute_instance.nomad_clients[0].network_interface[0].access_config[0].nat_ip}:8080"
    grafana    = "http://${google_compute_instance.nomad_clients[0].network_interface[0].access_config[0].nat_ip}:3000" 
    prometheus = "http://${google_compute_instance.nomad_clients[0].network_interface[0].access_config[0].nat_ip}:9090"
  }
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