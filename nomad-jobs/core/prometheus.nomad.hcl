job "prometheus" {
  datacenters = ["dc1"]
  type = "service"

  group "prometheus" {
    count = 1

    volume "prometheus_data" {
      type      = "host"
      read_only = false
      source    = "prometheus_data"
    }

    network {
      port "prometheus_ui" {
        to = 9090
      }
    }

    service {
      name = "prometheus"
      tags = [
        "traefik.enable=true",
        "traefik.http.routers.prometheus.rule=Host(`prometheus.hashistack.local`)",
        "traefik.http.services.prometheus.loadbalancer.server.port=9090"
      ]
      port = "prometheus_ui"
      
      check {
        type     = "http"
        path     = "/-/healthy"
        interval = "10s"
        timeout  = "3s"
      }
    }

    task "prometheus" {
      driver = "docker"

      config {
        image = "prom/prometheus:latest"
        ports = ["prometheus_ui"]
        args = [
          "--config.file=/etc/prometheus/prometheus.yml",
          "--storage.tsdb.path=/prometheus",
          "--web.enable-lifecycle"
        ]
      }

      volume_mount {
        volume      = "prometheus_data"
        destination = "/prometheus"
        read_only   = false
      }

      resources {
        cpu    = 500
        memory = 512
      }
    }
  }
}