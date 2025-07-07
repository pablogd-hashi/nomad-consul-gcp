job "loki" {
  region      = "global"
  datacenters = ["*"]
  type        = "service"

  group "loki" {
    count = 1

    volume "loki-data" {
      type   = "host"
      source = "loki-data"
    }

    restart {
      attempts = 2
      interval = "30m"
      delay    = "15s"
      mode     = "fail"
    }

    task "loki" {
      driver = "docker"

      volume_mount {
        volume      = "loki-data"
        destination = "/loki"
      }

      template {
        change_mode = "noop"
        destination = "local/loki-config.yml"
        data = <<EOH
auth_enabled: false

server:
  http_listen_port: 3100

ingester:
  lifecycler:
    address: 127.0.0.1
    ring:
      kvstore:
        store: inmemory
      replication_factor: 1
    final_sleep: 0s
  chunk_idle_period: 5m
  chunk_retain_period: 30s

schema_config:
  configs:
    - from: 2020-10-24
      store: boltdb
      object_store: filesystem
      schema: v11
      index:
        prefix: index_
        period: 168h

storage_config:
  boltdb:
    directory: /loki/index
  filesystem:
    directory: /loki/chunks

limits_config:
  enforce_metric_name: false
  reject_old_samples: true
  reject_old_samples_max_age: 168h

chunk_store_config:
  max_look_back_period: 0s

table_manager:
  retention_deletes_enabled: false
  retention_period: 0s
EOH
      }

      config {
        image = "grafana/loki:latest"
        ports = ["loki"]

        volumes = [
          "local/loki-config.yml:/etc/loki/local-config.yaml"
        ]

        args = [
          "-config.file=/etc/loki/local-config.yaml"
        ]
      }

      service {
        name = "loki"
        tags = ["logging", "loki"]
        port = 3100
        address_mode = "driver"

        check {
          name     = "loki alive"
          type     = "http"
          path     = "/ready"
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

    task "promtail" {
      driver = "docker"

      template {
        change_mode = "noop"
        destination = "local/promtail-config.yml"
        data = <<EOH
server:
  http_listen_port: 9080
  grpc_listen_port: 0

positions:
  filename: /tmp/positions.yaml

clients:
  - url: http://localhost:3100/loki/api/v1/push

scrape_configs:
  - job_name: journal
    journal:
      max_age: 12h
      labels:
        job: systemd-journal
        host: {{ env "NOMAD_ALLOC_NAME" }}
    relabel_configs:
      - source_labels: ['__journal__systemd_unit']
        target_label: 'unit'
      - source_labels: ['__journal__hostname']
        target_label: 'hostname'
    pipeline_stages:
      - match:
          selector: '{unit="consul.service"}'
          stages:
            - regex:
                expression: '(?P<timestamp>\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z)\s+\[(?P<level>\w+)\]\s+(?P<message>.*)'
            - labels:
                level:
      - match:
          selector: '{unit="nomad.service"}'
          stages:
            - regex:
                expression: '(?P<timestamp>\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z)\s+\[(?P<level>\w+)\]\s+(?P<message>.*)'
            - labels:
                level:

  - job_name: nomad-logs
    static_configs:
      - targets:
          - localhost
        labels:
          job: nomad-alloc-logs
          __path__: /alloc/logs/*.std*
    pipeline_stages:
      - match:
          selector: '{job="nomad-alloc-logs"}'
          stages:
            - regex:
                expression: '^(?P<timestamp>\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z)\s+(?P<message>.*)'
            - timestamp:
                source: timestamp
                format: RFC3339Nano
EOH
      }

      config {
        image = "grafana/promtail:latest"
        
        volumes = [
          "local/promtail-config.yml:/etc/promtail/config.yml",
          "/var/log/journal:/var/log/journal:ro",
          "/etc/machine-id:/etc/machine-id:ro",
          "/alloc/logs:/alloc/logs:ro"
        ]

        args = [
          "-config.file=/etc/promtail/config.yml"
        ]

        privileged = true
      }

      service {
        name = "promtail"
        tags = ["logging", "promtail"]
        port = 9080
        address_mode = "driver"

        check {
          name     = "promtail alive"
          type     = "http"
          path     = "/ready"
          interval = "10s"
          timeout  = "2s"
          address_mode = "driver"
        }
      }

      resources {
        cpu    = 100
        memory = 256
      }
    }

    network {
      port "loki" {
        static = 3100
        to     = 3100
      }
      port "promtail" {
        static = 9080
        to     = 9080
      }
    }
  }
}