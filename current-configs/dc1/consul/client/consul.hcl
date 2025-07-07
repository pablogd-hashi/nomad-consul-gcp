# DC1 Consul Client Configuration
# Extracted from clusters/dc1/terraform/template/template-client.tpl

datacenter = "dc1"
data_dir = "/opt/consul"
node_name = "client-node"
node_meta = {
  hostname = "hostname"
  gcp_instance = "gcp-instance-name"
  gcp_zone = "gcp-zone"
}
encrypt = "encryption-key"
retry_join = ["provider=gce project_name=gcp-project tag_value=consul-server zone_pattern=\"us-east2-[a-z]\""]
license_path = "/etc/consul.d/license.hclic"
log_level = "DEBUG"

tls {
   defaults {
      ca_file = "/etc/consul.d/tls/consul-agent-ca.pem"
      verify_incoming = false
      verify_outgoing = true
   }
   internal_rpc {
      verify_server_hostname = false
   }
}

acl = {
  enabled = true
  default_policy = "deny"
  enable_token_persistence = true
  tokens = {
    initial_management = "bootstrap-token"
    agent = "bootstrap-token"
    dns = "bootstrap-token"
  }
}

audit {
  enabled = true
  sink "dc1_sink" {
    type   = "file"
    format = "json"
    path   = "/opt/consul/audit/audit.json"
    delivery_guarantee = "best-effort"
    rotate_duration = "24h"
    rotate_max_files = 15
    rotate_bytes = 25165824
    mode = "644"
  }
}

reporting {
  license {
    enabled = false
  }
}

partition = "default"

client_addr = "0.0.0.0"
bind_addr = "PRIVATE_IP"
recursors = ["8.8.8.8","1.1.1.1"]

ports {
  https = 8501
  grpc = 8502
  grpc_tls = 8503
}