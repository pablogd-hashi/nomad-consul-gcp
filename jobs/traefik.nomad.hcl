# jobs/traefik.nomad.hcl
job "traefik" {
  datacenters = ["dc1"]
  type = "service"

  group "traefik" {
    count = 2

    network {
      port "http" {
        static = 80
      }
      port "api" {
        static = 8080
      }
    }

    service {
      name = "traefik"
      tags = [
        "traefik.enable=true",
        "traefik.http.routers.dashboard.rule=Host(`traefik.hashistack.local`)",
        "traefik.http.routers.dashboard.service=api@internal",
        "traefik.http.routers.dashboard.middlewares=dashboard-auth",
        "traefik.http.middlewares.dashboard-auth.basicauth.users=admin:$$2y$$10$$2b2cu/biJgjOpmzqZjxdAOGMSFTvLRVnCIKZwEJYcqCZhPQKPHT0W"
      ]
      port = "http"
      
      check {
        name     = "alive"
        type     = "tcp"
        port     = "http"
        interval = "10s"
        timeout  = "2s"
      }
    }

    task "traefik" {
      driver = "docker"

      config {
        image        = "traefik:v3.0"
        network_mode = "host"
        ports        = ["http", "api"]

        volumes = [
          "local/traefik.yml:/etc/traefik/traefik.yml",
        ]
      }

      template {
        data = <<EOF
global:
  checkNewVersion: false
  sendAnonymousUsage: false

serversTransport:
  insecureSkipVerify: true

entryPoints:
  web:
    address: ":80"
  traefik:
    address: ":8080"

providers:
  consul:
    rootKey: "traefik"
  consulCatalog:
    prefix: traefik
    exposedByDefault: false
    endpoints:
      - "127.0.0.1:8500"
    defaultRule: Host(`{{ .Name }}.hashistack.local`)

api:
  dashboard: true
  insecure: true

ping: {}

log:
  level: INFO

accessLog: {}

metrics:
  prometheus:
    addEntryPointsLabels: true
    addServicesLabels: true
    addRoutersLabels: true
EOF
        destination = "local/traefik.yml"
      }

      resources {
        cpu    = 200
        memory = 256
      }
    }
  }
}
