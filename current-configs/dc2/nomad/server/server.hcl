# DC2 Nomad Server Configuration - Server Block
# Extracted from clusters/dc2/terraform/template/template.tpl

server {
  enabled = true
  bootstrap_expect = 3
  server_join {
    retry_join = ["provider=gce project_name=gcp-project tag_value=nomad-server"]
  }
  license_path = "/etc/nomad.d/license.hclic"
}