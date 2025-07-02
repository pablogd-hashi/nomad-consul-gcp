variable "back_version" {
  type = string
  default = "v0.26.2"
}
variable "datacenter" {
  type = string
  default = "dc1"
}
variable "replicas_private" {
  type = number
  default = 2
}
variable "replicas_public" {
  type = number
  default = 2
}

job "backend-services" {
  datacenters = [var.datacenter]
  group "public" {
    count = var.replicas_public
    network {
      mode = "bridge"
      port "public-api" {
        to = 9090
      }
    }
    service {
      name = "public-api"
      tags = [
        "api",
        "public",
        "traefik.enable=true",
        "traefik.http.routers.public-api.rule=PathPrefix(`/api/public`)",
        "traefik.http.routers.public-api.entrypoints=web"
      ]
      port = "public-api"
      address_mode = "host"

      connect {
        sidecar_service {
          proxy {
            transparent_proxy {}
          } 
        }
      }
    }

    task "public-api" {
      driver = "docker"

      config {
        image          = "nicholasjackson/fake-service:${var.back_version}"
      }

      env {
        PORT = "${NOMAD_PORT_public-api}"
        LISTEN_ADDR = "0.0.0.0:9090"
        MESSAGE = "Hello World from Public API @${NOMAD_DC}"
        NAME = "Public_API@${NOMAD_DC}"
      }
    }
  }
  group "private" {
    count = var.replicas_private
    network {
      mode = "bridge"
      port "private-api" {
        to = 9090
      }
      # port "connect-proxy-private-api" {
      #   static = 25000
      # }
    }
    service {
      name = "private-api"
      tags = ["api","private"]
      port = "private-api"
      address_mode = "host"

      connect {
        sidecar_service {
          proxy {
            transparent_proxy {}
          } 
        }
      }
    }

    task "private-api" {
      driver = "docker"

    
      config {
        image          = "nicholasjackson/fake-service:${var.back_version}"
        ports          = ["private-api"]
      }

      # identity {
      #   env  = true
      #   file = true
      # }

      env {
        PORT = "9090"
        LISTEN_ADDR = "0.0.0.0:9090"
        MESSAGE = "Hello World from Private API @${NOMAD_DC}"
        NAME = "Private_API@${NOMAD_DC}"
      }
    }
  }
}
