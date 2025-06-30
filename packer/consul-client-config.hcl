# Consul Client Configuration for Nomad Integration
datacenter = "${CONSUL_DATACENTER:-dc1}"
data_dir = "/opt/consul/data"
log_level = "${CONSUL_LOG_LEVEL:-INFO}"
node_name = "$INSTANCE_NAME"
bind_addr = "$PRIVATE_IP"
client_addr = "0.0.0.0"
retry_join = ["provider=gce project_name=${PROJECT_ID} tag_value=consul-server"]

# Service Mesh (Consul Connect)
connect {
  enabled = true
}

# Enterprise License
license_path = "/opt/consul/consul.lic"
encrypt = "$CONSUL_ENCRYPT_KEY"

# ACL Configuration
acl = {
  enabled = ${ENABLE_ACLS:-true}
  default_policy = "deny"
  enable_token_persistence = true
  tokens {
    default = "${CONSUL_TOKEN}"
  }
}

# Auto Config for easier setup
auto_config {
  enabled = true
  intro_token = "${CONSUL_INTRO_TOKEN}"
  server_addresses = ["${CONSUL_SERVERS}"]
}

# Ports Configuration - crucial for Nomad integration
ports {
  grpc = 8502        # Required for Consul Connect
  grpc_tls = 8503    # Required for TLS
  http = 8500        
  https = 8501
  dns = 8600
}

# Telemetry for monitoring
telemetry {
  prometheus_retention_time = "24h"
  disable_hostname = true
  metrics_prefix = "consul"
}

# Log configuration
log_json = true
enable_syslog = false

# TLS Configuration (when enabled)
verify_incoming = false
verify_outgoing = false
verify_server_hostname = false
ca_file = "/opt/consul/tls/consul-agent-ca.pem"
cert_file = "/opt/consul/tls/consul-agent.pem"
key_file = "/opt/consul/tls/consul-agent-key.pem"

# Service registration
services {
  name = "consul-client"
  tags = ["consul-client"]
  port = 8500
  check {
    http = "http://localhost:8500/v1/status/leader"
    interval = "10s"
    timeout = "3s"
  }
}