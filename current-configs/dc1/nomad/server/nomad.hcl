# DC1 Nomad Server Configuration
# Extracted from clusters/dc1/terraform/template/template.tpl

datacenter = "dc1"
data_dir = "/opt/nomad"
acl  {
  enabled = true
}
consul {
  token = "bootstrap-token"
  enabled = true

  service_identity {
    aud = ["consul.io"]
    ttl = "1h"
  }

  task_identity {
    aud = ["consul.io"]
    ttl = "1h"
  }
}