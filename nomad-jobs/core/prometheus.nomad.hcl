job "prometheus" {
  datacenters = ["dc1"]
  type = "service"

  group "prometheus" {
    count = 1


    network {
      mode = "bridge"
      port "prometheus_ui" {
        static = 9090
        to = 9090
      }
    }

    service {
      name = "prometheus"
      tags = ["monitoring", "metrics"]
      port = "prometheus_ui"
      address_mode = "host"

      connect {
        sidecar_service {
          proxy {
            transparent_proxy {}
          } 
        }
      }

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
        mount {
          type   = "bind"
          source = "local/prometheus.yml"
          target = "/etc/prometheus/prometheus.yml"
        }
        args = [
          "--config.file=/etc/prometheus/prometheus.yml",
          "--storage.tsdb.path=/prometheus",
          "--web.enable-lifecycle"
        ]
      }

      template {
        data = <<EOF
global:
  scrape_interval: 5s
  evaluation_interval: 5s

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'nomad-servers'
    static_configs:
      - targets: ['10.0.0.2:4646', '10.0.0.3:4646', '10.0.0.4:4646']
    scrape_interval: 5s
    metrics_path: /v1/metrics
    params:
      format: ['prometheus']

  - job_name: 'nomad-clients'
    static_configs:
      - targets: ['10.0.0.5:4646', '10.0.0.6:4646']
    scrape_interval: 5s
    metrics_path: /v1/metrics
    params:
      format: ['prometheus']

  - job_name: 'consul-servers'
    consul_sd_configs:
      - server: 'localhost:8500'
        tags: ['hashistack']
    relabel_configs:
      - source_labels: [__meta_consul_tags]
        regex: '.*,server,.*'
        action: keep
      - source_labels: [__address__]
        target_label: __address__
        replacement: '${1}:8500'
    metrics_path: '/v1/agent/metrics'
    params:
      format: ['prometheus']

  - job_name: 'consul-clients'
    consul_sd_configs:
      - server: 'localhost:8500'
        tags: ['hashistack']
    relabel_configs:
      - source_labels: [__meta_consul_tags]
        regex: '.*,client,.*'
        action: keep
      - source_labels: [__address__]
        target_label: __address__
        replacement: '${1}:8500'
    metrics_path: '/v1/agent/metrics'
    params:
      format: ['prometheus']
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