job "traefik-test" {
  datacenters = ["dc1"]
  type = "service"

  group "traefik" {
    count = 1

    network {
      port "api" {
        static = 8091
      }
    }

    service {
      name = "traefik-test"
      port = "api"

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
        ports        = ["api"]
        args = [
          "--api.dashboard=true",
          "--api.insecure=true",
          "--entrypoints.traefik.address=:8091",
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