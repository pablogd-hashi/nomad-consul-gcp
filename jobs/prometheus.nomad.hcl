# jobs/prometheus.nomad.hcl
job "prometheus" {
  datacenters = ["dc1"]
  type = "service"

  group "prometheus" {
    count = 1

    network {
      port "prometheus_ui" {
        to = 9090
      }
    }

    volume "prometheus_data" {
      type      = "host"
      read_only = false
      source    = "prometheus_data"
    }

    service {
      name = "prometheus"
      tags = [
        "traefik.enable=true",
        "traefik.http.routers.prometheus.rule=Host(`prometheus.hashistack.local`)",
        "traefik.http.routers.prometheus.service=prometheus",
        "traefik.http.services.prometheus.loadbalancer.server.port=9090"
      ]
      port = "prometheus_ui"
      
      check {
        type     = "http"
        path     = "/-/healthy"
        interval = "10s"
        timeout  = "3s"
      }
    }

    task "prometheus" {
      driver = "docker"

      config {
        image = "prom/prometheus:latest"
        ports = ["prometheus_ui"]
        
        volumes = [
          "local/prometheus.yml:/etc/prometheus/prometheus.yml",
        ]

        args = [
          "--config.file=/etc/prometheus/prometheus.yml",
          "--storage.tsdb.path=/prometheus",
          "--web.console.libraries=/etc/prometheus/console_libraries",
          "--web.console.templates=/etc/prometheus/consoles",
          "--web.enable-lifecycle",
          "--web.enable-admin-api"
        ]
      }

      volume_mount {
        volume      = "prometheus_data"
        destination = "/prometheus"
        read_only   = false
      }

      template {
        data = <<EOF
global:
  scrape_interval: 15s
  evaluation_interval: 15s

rule_files:
  # - "first_rules.yml"
  # - "second_rules.yml"

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'consul'
    consul_sd_configs:
      - server: '{{ env "CONSUL_HTTP_ADDR" | default "127.0.0.1:8500" }}'
        services: []
    relabel_configs:
      - source_labels: [__meta_consul_tags]
        regex: .*,prometheus,.*
        action: keep
      - source_labels: [__meta_consul_service]
        target_label: job

  - job_name: 'nomad'
    consul_sd_configs:
      - server: '{{ env "CONSUL_HTTP_ADDR" | default "127.0.0.1:8500" }}'
        services: ['nomad']
    relabel_configs:
      - source_labels: [__meta_consul_tags]
        regex: .*,http,.*
        action: keep
      - source_labels: [__meta_consul_service]
        target_label: job
      - source_labels: [__meta_consul_node]
        target_label: instance

  - job_name: 'traefik'
    static_configs:
      - targets: ['traefik.service.consul:8080']
    metrics_path: /metrics
EOF
        destination = "local/prometheus.yml"
      }

      resources {
        cpu    = 500
        memory = 512
      }
    }
  }
}