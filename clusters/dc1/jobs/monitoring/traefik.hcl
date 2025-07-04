job "traefik" {
  region      = "global"
  datacenters = ["*"]
  type = "service"

  group "traefik" {
    count = 1



    task "traefik" {
      driver = "docker"

      config {
        image        = "traefik:v3.0"
        network_mode = "host"
        args = [
          "--api.dashboard=true",
          "--api.insecure=true",
          "--entrypoints.web.address=:80",
          "--entrypoints.websecure.address=:443",
          "--entrypoints.traefik.address=:8080",
          "--providers.file.filename=/local/dynamic.yml",
          "--certificatesresolvers.letsencrypt.acme.tlschallenge=true",
          "--certificatesresolvers.letsencrypt.acme.email=admin@example.com",
          "--certificatesresolvers.letsencrypt.acme.storage=/local/acme.json",
          "--ping=true"
        ]
      }

      service {
        name = "traefik"
        tags = ["loadbalancer", "proxy"]
        port = 80
        address_mode = "driver"

        check {
          name     = "alive"
          type     = "http"
          port     = 8080
          path     = "/ping"
          interval = "10s"
          timeout  = "2s"
          address_mode = "driver"
        }
      }

      service {
        name = "traefik-https"
        tags = ["loadbalancer", "proxy", "https"]
        port = 443
        address_mode = "driver"
      }

      template {
        data = <<EOH
http:
  routers:
    prometheus-http:
      rule: "Host(`prometheus.hc-1031dcc8d7c24bfdbb4c08979b0.gcp.sbx.hashicorpdemo.com`)"
      service: prometheus
      entryPoints:
        - web
    grafana-http:
      rule: "Host(`grafana.hc-1031dcc8d7c24bfdbb4c08979b0.gcp.sbx.hashicorpdemo.com`)"
      service: grafana
      entryPoints:
        - web
  middlewares:
    redirect-to-https:
      redirectScheme:
        scheme: https
        permanent: true
  services:
    prometheus:
      loadBalancer:
        servers:
          - url: "http://localhost:9090"
    grafana:
      loadBalancer:
        servers:
          - url: "http://localhost:3000"
EOH
        destination = "local/dynamic.yml"
      }

      resources {
        cpu    = 200
        memory = 256
      }
    }
  }
}