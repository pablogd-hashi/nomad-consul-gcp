job "consul-connect-proxy" {
  datacenters = ["dc1"]
  type = "service"

  group "proxy" {
    count = 2

    network {
      mode = "bridge"
    }

    service {
      name = "consul-connect-proxy"
      tags = ["proxy", "consul-connect"]
      port = "20000"
      
      connect {
        sidecar_service {}
      }
    }

    task "consul-connect-proxy" {
      driver = "docker"
      
      config {
        image = "consul:1.17.0"
        command = "consul"
        args = [
          "connect", "proxy",
          "-sidecar-for", "consul-connect-proxy"
        ]
      }

      resources {
        cpu    = 200
        memory = 128
      }
    }
  }
}