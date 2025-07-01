# Enhanced Grafana with DNS routing
job "grafana-dns" {
  datacenters = ["dc1"]
  type = "service"

  group "grafana" {
    count = 1

    network {
      mode = "bridge"
      port "grafana_ui" {
        static = 3000
        to = 3000
      }
    }

    service {
      name = "grafana"
      tags = [
        "monitoring", 
        "dashboard",
        "traefik.enable=true",
        "traefik.http.routers.grafana.rule=Host(`grafana.hashistack.local`) || Host(`grafana.YOUR-DOMAIN.com`)",
        "traefik.http.routers.grafana.service=grafana",
        "traefik.http.services.grafana.loadbalancer.server.port=3000"
      ]
      port = "grafana_ui"
      address_mode = "host"

      connect {
        sidecar_service {
          proxy {
            transparent_proxy {}
            upstreams {
              destination_name = "prometheus"
              local_bind_port  = 9090
            }
          } 
        }
      }

      check {
        type = "http"
        name = "grafana-health"
        path = "/api/health"
        interval = "10s"
        timeout = "5s"
      }
    }

    task "grafana" {
      driver = "docker"

      config {
        image = "grafana/grafana:latest"
        ports = ["grafana_ui"]
      }

      env {
        GF_SECURITY_ADMIN_PASSWORD = "admin"
        GF_SECURITY_ADMIN_USER = "admin"
        GF_INSTALL_PLUGINS = "grafana-clock-panel,grafana-simple-json-datasource"
      }

      resources {
        cpu = 200
        memory = 512
      }
    }
  }
}