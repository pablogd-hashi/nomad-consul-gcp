job "grafana" {
  datacenters = ["dc1"]
  type = "service"

  group "grafana" {
    count = 1

    network {
      port "grafana_ui" {
        to = 3000
      }
    }

    volume "grafana_data" {
      type      = "host"
      read_only = false
      source    = "grafana_data"
    }

    service {
      name = "grafana"
      tags = [
        "traefik.enable=true",
        "traefik.http.routers.grafana.rule=Host(`grafana.hashistack.local`)",
        "traefik.http.routers.grafana.service=grafana",
        "traefik.http.services.grafana.loadbalancer.server.port=3000"
      ]
      port = "grafana_ui"
      
      check {
        type     = "http"
        path     = "/api/health"
        interval = "10s"
        timeout  = "3s"
      }
    }

    task "grafana" {
      driver = "docker"

      config {
        image = "grafana/grafana:latest"
        ports = ["grafana_ui"]
        
        volumes = [
          "local/grafana.ini:/etc/grafana/grafana.ini",
          "local/datasources.yml:/etc/grafana/provisioning/datasources/datasources.yml",
          "local/dashboards.yml:/etc/grafana/provisioning/dashboards/dashboards.yml"
        ]
      }

      volume_mount {
        volume      = "grafana_data"
        destination = "/var/lib/grafana"
        read_only   = false
      }

      template {
        data = <<EOF
[server]
http_addr = 0.0.0.0
http_port = 3000
domain = grafana.hashistack.local

[security]
admin_user = admin
admin_password = admin
allow_embedding = true

[users]
allow_sign_up = false

[auth.anonymous]
enabled = true
org_role = Viewer

[analytics]
reporting_enabled = false
check_for_updates = false

[log]
mode = console
level = info
EOF
        destination = "local/grafana.ini"
      }

      template {
        data = <<EOF
apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus.service.consul:9090
    isDefault: true
    editable: true
EOF
        destination = "local/datasources.yml"
      }

      template {
        data = <<EOF
apiVersion: 1

providers:
  - name: 'default'
    orgId: 1
    folder: ''
    type: file
    disableDeletion: false
    updateIntervalSeconds: 10
    allowUiUpdates: true
    options:
      path: /etc/grafana/provisioning/dashboards
EOF
        destination = "local/dashboards.yml"
      }

      env {
        GF_SECURITY_ADMIN_PASSWORD = "admin"
        GF_INSTALL_PLUGINS = "grafana-clock-panel,grafana-simple-json-datasource"
      }

      resources {
        cpu    = 200
        memory = 512
      }
    }
  }
}
