job "terramino" {
  datacenters = ["dc1"]
  type = "service"

  group "terramino" {
    count = 1

    network {
      port "http" {
        to = 80
      }
    }

    service {
      name = "terramino"
      tags = [
        "traefik.enable=true",
        "traefik.http.routers.terramino.rule=Host(`terramino.hashistack.local`)",
        "traefik.http.services.terramino.loadbalancer.server.port=80"
      ]
      port = "http"
      
      check {
        type     = "http"
        path     = "/"
        interval = "10s"
        timeout  = "2s"
      }
    }

    task "web" {
      driver = "docker"

      config {
        image = "nginx:alpine"
        ports = ["http"]
      }

      artifact {
        source = "https://github.com/hashicorp-education/learn-terramino/archive/refs/heads/main.zip"
        destination = "local/"
      }

      resources {
        cpu    = 200
        memory = 256
      }
    }
  }
}
