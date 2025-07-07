# DC2 Consul Server Configuration - Server Block
# Extracted from clusters/dc2/terraform/template/template.tpl

server = true
bootstrap_expect = 3

ui = true
client_addr = "0.0.0.0"
bind_addr = "PRIVATE_IP"

connect {
  enabled = true
}

ui_config {
  enabled = true
  metrics_provider = "prometheus"
  metrics_proxy {
    base_url = "http://localhost:9090"
  }
  dashboard_url_templates {
    service = "http://localhost:3000/d/lDlaj-NGz/service-overview?orgId=1&var-service={{Service.Name}}&var-namespace={{Service.Namespace}}&var-partition={{Service.Partition}}&var-dc={{Datacenter}}"
  }
}

ports {
  https = 8501
  grpc = 8502
  grpc_tls = 8503
}