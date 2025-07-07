# DC1 Nomad Client Configuration
# Extracted from clusters/dc1/terraform/template/template-client.tpl

datacenter = "dc1"
data_dir = "/opt/nomad"
acl  {
  enabled = true
}
consul {
  token = "bootstrap-token"
  
  service_identity {
    aud = ["consul.io"]
    ttl = "1h"
  }

  task_identity {
    aud = ["consul.io"]
    ttl = "1h"
  }
}

telemetry {
  collection_interval = "1s"
  disable_hostname = true
  prometheus_metrics = true
  publish_allocation_metrics = true
  publish_node_metrics = true
}