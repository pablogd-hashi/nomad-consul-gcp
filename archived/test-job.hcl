job "test" {
  datacenters = ["dc1"]
  type = "service"

  group "web" {
    count = 1

    task "nginx" {
      driver = "docker"

      config {
        image = "nginx:latest"
        ports = ["http"]
      }

      resources {
        cpu    = 100
        memory = 64
      }
    }

    network {
      port "http" {
        static = 8080
      }
    }
  }
}