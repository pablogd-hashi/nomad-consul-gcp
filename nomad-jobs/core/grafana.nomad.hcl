job "grafana" {
  datacenters = ["dc1"]
  type = "service"

  group "grafana" {
    count = 1

    volume "grafana_data" {
      type      = "host"
      read_only = false
      source    = "grafana_data"
    }

    network {
      port "grafana_ui" {
        to = 3000
      }
    }

    service {
      name = "grafana"
      tags = [
        "traefik.enable=true",
        "traefik.http.routers.grafana.rule=Host(`grafana.hashistack.local`)",
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
      }

      volume_mount {
        volume      = "grafana_data"
        destination = "/var/lib/grafana"
        read_only   = false
      }

      env {
        GF_SECURITY_ADMIN_PASSWORD = "admin"
      }

      resources {
        cpu    = 200
        memory = 512
      }
    }
  }
}