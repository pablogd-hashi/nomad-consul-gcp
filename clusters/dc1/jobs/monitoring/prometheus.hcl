job "prometheus" {
  region      = "global"
  datacenters = ["*"]
  type        = "service"

  group "monitoring" {
    count = 1



    restart {
      attempts = 2
      interval = "30m"
      delay    = "15s"
      mode     = "fail"
    }

    ephemeral_disk {
      size = 300
    }


    task "prometheus" {
      template {
        change_mode = "noop"
        destination = "local/prometheus.yml"

        data = <<EOH
---
global:
  scrape_interval:     5s
  evaluation_interval: 5s

scrape_configs:

  - job_name: 'nomad-servers'
    static_configs:
    - targets: ['{{ env "NOMAD_IP_prometheus_ui" }}:4646']
    metrics_path: /v1/metrics
    params:
      format: ['prometheus']
    scrape_interval: 10s

  - job_name: 'nomad-clients'
    static_configs: 
    - targets: ['{{ env "NOMAD_IP_prometheus_ui" }}:4646']
    metrics_path: /v1/metrics
    params:
      format: ['prometheus']
    scrape_interval: 10s

  - job_name: 'consul'
    static_configs:
    - targets: ['{{ env "NOMAD_IP_prometheus_ui" }}:8500']
    metrics_path: /v1/agent/metrics
    params:
      format: ['prometheus']
    scrape_interval: 10s
EOH
      }

      driver = "docker"

      config {
        image = "prom/prometheus:latest"
        network_mode = "host"

        volumes = [
          "local/prometheus.yml:/etc/prometheus/prometheus.yml",
        ]

      }

      service {
        name = "prometheus"
        tags = [
          "monitoring", 
          "metrics",
          "traefik.enable=true",
          "traefik.http.routers.prometheus.rule=PathPrefix(`/prometheus`)",
          "traefik.http.routers.prometheus.entrypoints=web",
          "traefik.http.services.prometheus.loadbalancer.server.port=9090"
        ]
        port = 9090
        address_mode = "driver"

        check {
          name     = "prometheus_ui port alive"
          type     = "http"
          path     = "/-/healthy"
          interval = "10s"
          timeout  = "2s"
          address_mode = "driver"
        }
      }


      resources {
        cpu    = 200
        memory = 512
      }
    }
  }
}