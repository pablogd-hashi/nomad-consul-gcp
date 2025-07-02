job "counting-app" {
  datacenters = ["dc1"]
  type        = "service"

  group "api" {
    count = 2

    network {
      mode = "bridge"
      port "api" {
        to = 9001
      }
    }

    service {
      name = "counting-api"
      port = "api"
      tags = ["api", "counting"]

      connect {
        sidecar_service {
          proxy {
            transparent_proxy {}
          }
        }
      }

      check {
        name     = "Counting API HTTP"
        type     = "http"
        path     = "/"
        interval = "10s"
        timeout  = "3s"
      }
    }

    task "api" {
      driver = "docker"

      config {
        image = "hashicorp/counting-service:0.0.2"
        ports = ["api"]
      }

      resources {
        cpu    = 200
        memory = 128
      }
    }
  }

  group "dashboard" {
    count = 1

    network {
      mode = "bridge"
      port "http" {
        to = 9002
      }
    }

    service {
      name = "counting-dashboard"
      port = "http"
      tags = ["dashboard", "web", "urlprefix-/counting"]

      connect {
        sidecar_service {
          proxy {
            transparent_proxy {}
            upstreams {
              destination_name = "counting-api"
              local_bind_port  = 9001
            }
          }
        }
      }

      check {
        name     = "Dashboard HTTP"
        type     = "http"
        path     = "/"
        interval = "10s"
        timeout  = "3s"
      }
    }

    task "dashboard" {
      driver = "docker"

      config {
        image = "hashicorp/dashboard-service:0.0.4"
        ports = ["http"]
      }

      env {
        COUNTING_SERVICE_URL = "http://localhost:9001"
      }

      resources {
        cpu    = 200
        memory = 128
      }
    }
  }
}