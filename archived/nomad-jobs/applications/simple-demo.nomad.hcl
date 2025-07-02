job "simple-demo" {
  datacenters = ["dc1"]
  type        = "service"

  group "demo" {
    count = 1

    network {
      port "http" {
        static = 8082
      }
    }

    service {
      name = "simple-demo"
      port = "http"
      tags = ["demo", "web"]

      check {
        name     = "Demo HTTP"
        type     = "http"
        path     = "/"
        interval = "10s"
        timeout  = "3s"
      }
    }

    task "demo" {
      driver = "docker"

      config {
        image = "hashicorp/http-echo"
        ports = ["http"]
        args = [
          "-listen=:8082",
          "-text=Hello from HashiCorp Demo App! This is running on Nomad with Consul service discovery."
        ]
      }

      resources {
        cpu    = 100
        memory = 64
      }
    }
  }
}