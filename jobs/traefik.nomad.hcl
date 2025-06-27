job "traefik" {
  datacenters = ["dc1"]
  type = "service"

  group "traefik" {
    count = 2

    network {
      port "http" {
        static = 80
      }
      port "api" {
        static = 8080
      }
    }

    service {
      name = "traefik"
      port = "http"
      
      check {
        name     = "alive"
        type     = "http"
        port     = "api"
        path     = "/ping"
        interval = "10s"
        timeout  = "2s"
      }
    }

    task "traefik" {
      driver = "docker"

      config {
        image        = "traefik:v3.0"
        network_mode = "host"
        ports        = ["http", "api"]
        args = [
          "--api.dashboard=true",
          "--api.insecure=true",
          "--entrypoints.web.address=:80",
          "--entrypoints.traefik.address=:8080",
          "--providers.consul.endpoints=127.0.0.1:8500",
          "--providers.consulcatalog.prefix=traefik",
          "--providers.consulcatalog.exposedbydefault=false",
          "--providers.consulcatalog.endpoints=127.0.0.1:8500",
          "--ping=true"
        ]
      }

      resources {
        cpu    = 200
        memory = 256
      }
    }
  }
}