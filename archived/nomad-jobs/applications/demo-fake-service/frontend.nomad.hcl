variable "front_version" {
  type = string
  default = "v0.26.2"
}

variable "datacenter" {
  type = string
  default = "dc1"
}

job "front-service" {
  datacenters = [var.datacenter]

  group "frontend" {
    network {
      mode = "bridge"
      port "http" {
        to = 9090
      }
    }
    service {
      name = "front-service"
      tags = [
        "web",
        "frontend",
        "traefik.enable=true",
        "traefik.http.routers.frontend.rule=PathPrefix(`/frontend`)",
        "traefik.http.routers.frontend.entrypoints=web"
      ]
      port = "http"
      address_mode = "host"
    
      connect {
        sidecar_service {
          proxy {
            transparent_proxy {}
            upstreams {
              destination_name = "public-api"
              local_bind_port  = 8081
            }
            upstreams {
              destination_name = "private-api"
              local_bind_port  = 8082
            }
          } 
        }
      }
    }

    task "web" {
      driver = "docker"

      config {
        image          = "nicholasjackson/fake-service:${var.front_version}"
        ports          = ["http"]
      }

      # identity {
      #   env  = true
      #   file = true
      # }

      # resources {
      #   cpu    = 500
      #   memory = 256
      # }
      env {
        PORT = "9090"
        LISTEN_ADDR = "0.0.0.0:9090"
        MESSAGE = "Hello World from Frontend V1 @${NOMAD_DC}"
        NAME = "web"
        UPSTREAM_URIS = "http://localhost:8081,http://localhost:8082"
      }
    }
  }
}
