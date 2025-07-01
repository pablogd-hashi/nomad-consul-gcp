variable "front_version" {
  type = string
  default = "v0.26.2"
}

variable "datacenter" {
  type = string
  default = "dc1"
}

job "demo-frontend" {
  datacenters = [var.datacenter]

  group "frontend" {
    network {
      mode = "bridge"
      port "http" {
        to = 9090
      }
    }
    
    service {
      name = "demo-frontend"
      tags = ["web", "frontend"]
      port = "http"
      address_mode = "alloc"
    
      connect {
        sidecar_service {
          proxy {
            transparent_proxy {}
          } 
        }
      }
      
      check {
        type = "http"
        path = "/"
        interval = "10s"
        timeout = "5s"
      }
    }

    task "web" {
      driver = "docker"

      config {
        image = "nicholasjackson/fake-service:${var.front_version}"
        ports = ["http"]
      }

      env {
        PORT = "9090"
        LISTEN_ADDR = "0.0.0.0:9090"
        MESSAGE = "Hello from Demo Frontend - HashiStack Works!"
        NAME = "demo-frontend"
        UPSTREAM_URIS = "http://demo-backend.service.consul:9090"
      }

      resources {
        cpu = 200
        memory = 256
      }
    }
  }
}