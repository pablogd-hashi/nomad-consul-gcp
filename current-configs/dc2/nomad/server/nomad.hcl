# DC2 Nomad Server Configuration
# Extracted from clusters/dc2/terraform/template/template.tpl

datacenter = "dc2"
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