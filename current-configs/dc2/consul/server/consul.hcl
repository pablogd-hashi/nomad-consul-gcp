# DC2 Consul Server Configuration
# Extracted from clusters/dc2/terraform/template/template.tpl

datacenter = "dc2"
data_dir = "/opt/consul"
node_name = "server-node"
node_meta = {
  hostname = "hostname"
  gcp_instance = "gcp-instance-name"
  gcp_zone = "gcp-zone"
}
encrypt = "encryption-key"
retry_join = ["provider=gce project_name=gcp-project tag_value=consul-server zone_pattern=\"us-west2-[a-z]\""]
license_path = "/etc/consul.d/license.hclic"
log_level = "DEBUG"

tls {
   defaults {
      ca_file = "/etc/consul.d/tls/consul-agent-ca.pem"
      cert_file = "/etc/consul.d/tls/dc2-server-consul-0.pem"
      key_file = "/etc/consul.d/tls/dc2-server-consul-0-key.pem"
      verify_incoming = false
      verify_outgoing = true
      verify_server_hostname = false
   }
   internal_rpc {
      verify_server_hostname = true
   }
}

auto_encrypt {
  allow_tls = true
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
  sink "dc2_sink" {
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