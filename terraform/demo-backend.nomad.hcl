variable "back_version" {
  type = string
  default = "v0.26.2"
}

variable "datacenter" {
  type = string
  default = "dc1"
}

job "demo-backend" {
  datacenters = [var.datacenter]
  
  group "backend" {
    count = 2
    
    network {
      mode = "bridge"
      port "api" {
        to = 9090
      }
    }
    
    service {
      name = "demo-backend"
      tags = ["api", "backend"]
      port = "api"
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

    task "api" {
      driver = "docker"

      config {
        image = "nicholasjackson/fake-service:${var.back_version}"
        ports = ["api"]
      }

      env {
        PORT = "9090"
        LISTEN_ADDR = "0.0.0.0:9090"
        MESSAGE = "Hello from Demo Backend API - Data served successfully!"
        NAME = "demo-backend"
      }

      resources {
        cpu = 200
        memory = 256
      }
    }
  }
}