job "grafana" {
  region      = "global"
  datacenters = ["*"]
  type        = "service"

  group "grafana" {
    count = 1

    constraint {
      attribute = "${node.class}"
      value     = "client"
    }

    network {
      port "grafana_ui" {
        static = 3000
        to     = 3000
      }
    }

    service {
      name = "grafana"
      port = "grafana_ui"
      
      tags = [
        "monitoring",
        "grafana",
        "dashboard"
      ]

      check {
        name     = "Grafana UI"
        http     = "http://${NOMAD_ADDR_grafana_ui}/api/health"
        interval = "10s"
        timeout  = "3s"
      }

      connect {
        sidecar_service {}
      }
    }

    volume "grafana-data" {
      type   = "host"
      source = "grafana-data"
    }

    task "grafana" {
      driver = "docker"

      config {
        image = "grafana/grafana:latest"
        ports = ["grafana_ui"]
        
        mount {
          type   = "bind"
          source = "local/grafana.ini"
          target = "/etc/grafana/grafana.ini"
        }

        mount {
          type   = "bind"
          source = "local/datasources.yml"
          target = "/etc/grafana/provisioning/datasources/datasources.yml"
        }

        mount {
          type   = "bind"
          source = "local/dashboards.yml"
          target = "/etc/grafana/provisioning/dashboards/dashboards.yml"
        }
      }

      volume_mount {
        volume      = "grafana-data"
        destination = "/var/lib/grafana"
      }

      template {
        data = <<EOH
[server]
protocol = http
http_port = 3000
domain = localhost
root_url = %(protocol)s://%(domain)s/grafana/
serve_from_sub_path = true

[security]
admin_user = admin
admin_password = admin

[users]
allow_sign_up = false
allow_org_create = false
auto_assign_org = true
auto_assign_org_role = Viewer

[auth.anonymous]
enabled = false

[log]
mode = console
level = info

[panels]
disable_sanitize_html = false

[paths]
data = /var/lib/grafana
logs = /var/log/grafana
plugins = /var/lib/grafana/plugins
provisioning = /etc/grafana/provisioning
EOH
        destination = "local/grafana.ini"
      }

      template {
        data = <<EOH
apiVersion: 1

deleteDatasources:
  - name: Prometheus
    orgId: 1

datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    orgId: 1
    url: http://{{ range service "prometheus" }}{{ .Address }}:{{ .Port }}{{ end }}/prometheus
    basicAuth: false
    isDefault: true
    version: 1
    editable: false
    jsonData:
      httpMethod: POST
      manageAlerts: true
      prometheusType: Prometheus
      prometheusVersion: 2.40.0
      cacheLevel: 'High'
      disableRecordingRules: false
      incrementalQueryOverlapWindow: 10m
EOH
        destination = "local/datasources.yml"
      }

      template {
        data = <<EOH
apiVersion: 1

providers:
  - name: 'default'
    orgId: 1
    folder: ''
    type: file
    disableDeletion: false
    editable: true
    updateIntervalSeconds: 10
    allowUiUpdates: true
    options:
      path: /etc/grafana/provisioning/dashboards
EOH
        destination = "local/dashboards.yml"
      }

      resources {
        cpu    = 300
        memory = 512
      }

      env {
        GF_SECURITY_ADMIN_PASSWORD = "admin"
        GF_INSTALL_PLUGINS = "grafana-piechart-panel"
      }
    }
  }
}