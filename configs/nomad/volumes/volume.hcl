volume "grafana" {
  namespace = "default"
  type      = "host"
  plugin_id = "mkdir"

  capability {
    access_mode     = "single-node-single-writer"
    attachment_mode = "file-system"
  }
}

