# Nomad Server Configuration with Consul Integration
datacenter = "${NOMAD_DATACENTER:-dc1}"
data_dir = "/opt/nomad/data"
log_level = "${NOMAD_LOG_LEVEL:-INFO}"
name = "$INSTANCE_NAME"

# Enterprise License
license_path = "/opt/nomad/nomad.lic"

# Server Configuration
server {
  enabled = true
  bootstrap_expect = ${SERVER_COUNT:-3}
  
  server_join {
    retry_join = ["provider=gce project_name=${PROJECT_ID} tag_value=nomad-server"]
    retry_max = 3
    retry_interval = "15s"
  }
  
  # Enable Consul integration for server discovery
  consul_service_name = "nomad-server"
}

bind_addr = "$PRIVATE_IP"

# Consul Integration - Critical for Service Discovery
consul {
  # Consul connection settings
  address = "127.0.0.1:8500"
  server_service_name = "nomad-server"
  client_service_name = "nomad-client"
  
  # Auto-advertise services
  auto_advertise = true
  server_auto_join = true
  client_auto_join = true
  
  # ACL token for Consul API access
  token = "${NOMAD_CONSUL_TOKEN}"
  
  # Service registration settings
  tags = ["nomad-server", "scheduler"]
  
  # Enable Consul Connect integration
  server_http_check_name = "Nomad Server HTTP"
  server_serf_check_name = "Nomad Server Serf"
  server_rpc_check_name = "Nomad Server RPC"
  
  # Consul Connect
  ca_file = "/opt/consul/tls/consul-agent-ca.pem"
  cert_file = "/opt/consul/tls/consul-agent.pem"
  key_file = "/opt/consul/tls/consul-agent-key.pem"
  verify_ssl = false
  
  # Service mesh integration
  namespace = "default"
}

# ACL Configuration
acl {
  enabled = ${ENABLE_ACLS:-true}
  token_ttl = "30s"
  policy_ttl = "60s"
  role_ttl = "60s"
  replication_token = "${NOMAD_REPLICATION_TOKEN}"
}

# Telemetry for monitoring
telemetry {
  collection_interval = "1s"
  disable_hostname = true
  prometheus_metrics = true
  publish_allocation_metrics = true
  publish_node_metrics = true
  statsd_address = "127.0.0.1:8125"
}

# UI Configuration
ui {
  enabled = true
  consul {
    ui_url = "http://localhost:8500/ui"
  }
  vault {
    ui_url = "http://localhost:8200/ui"
  }
}

# TLS Configuration
tls {
  http = false
  rpc = false
  ca_file = "/opt/nomad/tls/nomad-agent-ca.pem"
  cert_file = "/opt/nomad/tls/nomad-agent.pem"
  key_file = "/opt/nomad/tls/nomad-agent-key.pem"
  verify_server_hostname = false
  verify_https_client = false
}

# Log configuration
log_json = true
enable_syslog = false

# Plugin configuration for CSI
plugin_dir = "/opt/nomad/plugins"

# Scheduler configuration
server {
  # Additional server-specific settings
  heartbeat_grace = "10s"
  min_heartbeat_ttl = "10s"
  max_heartbeats_per_second = 50.0
  failover_heartbeat_ttl = "300s"
  
  # Raft configuration
  raft_protocol = 3
  raft_multiplier = 1
  
  # Encryption
  encrypt = "${NOMAD_ENCRYPT_KEY}"
}

# Service registration
service {
  name = "nomad-server"
  tags = ["nomad", "server", "scheduler"]
  port = 4646
  check {
    name = "Nomad Server HTTP"
    http = "http://localhost:4646/v1/status/leader"
    interval = "10s"
    timeout = "3s"
  }
}