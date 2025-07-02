job "prometheus" {
  region      = "global"
  datacenters = ["*"]
  type        = "service"

  group "prometheus" {
    count = 1

    constraint {
      attribute = "${node.class}"
      value     = "client"
    }

    network {
      port "prometheus_ui" {
        static = 9090
        to     = 9090
      }
    }

    service {
      name = "prometheus"
      port = "prometheus_ui"
      
      tags = [
        "monitoring",
        "prometheus",
        "metrics"
      ]

      check {
        name     = "Prometheus UI"
        http     = "http://${NOMAD_ADDR_prometheus_ui}/-/healthy"
        interval = "10s"
        timeout  = "3s"
      }

      connect {
        sidecar_service {}
      }
    }

    task "prometheus" {
      driver = "docker"

      config {
        image = "prom/prometheus:latest"
        ports = ["prometheus_ui"]
        
        args = [
          "--config.file=/etc/prometheus/prometheus.yml",
          "--storage.tsdb.path=/prometheus",
          "--web.console.libraries=/etc/prometheus/console_libraries",
          "--web.console.templates=/etc/prometheus/consoles",
          "--web.enable-lifecycle",
          "--web.route-prefix=/prometheus",
          "--web.external-url=http://localhost/prometheus"
        ]

        mount {
          type   = "bind"
          source = "local/prometheus.yml"
          target = "/etc/prometheus/prometheus.yml"
        }

        mount {
          type   = "bind"
          source = "local/consul_rules.yml"
          target = "/etc/prometheus/consul_rules.yml"
        }

        mount {
          type   = "bind"
          source = "local/nomad_rules.yml"
          target = "/etc/prometheus/nomad_rules.yml"
        }
      }

      template {
        data = <<EOH
global:
  scrape_interval: 15s
  evaluation_interval: 15s

rule_files:
  - "consul_rules.yml"
  - "nomad_rules.yml"

scrape_configs:
  # Scrape Prometheus itself
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  # Scrape Consul servers
  - job_name: 'consul-servers'
    consul_sd_configs:
      - server: '{{ env "CONSUL_HTTP_ADDR" }}'
        services: []
        tags:
          - consul-server
    relabel_configs:
      - source_labels: [__meta_consul_tags]
        regex: .*consul-server.*
        action: keep
      - source_labels: [__meta_consul_service]
        target_label: job
      - source_labels: [__meta_consul_node]
        target_label: instance

  # Scrape Nomad servers
  - job_name: 'nomad-servers'
    consul_sd_configs:
      - server: '{{ env "CONSUL_HTTP_ADDR" }}'
        services: []
        tags:
          - nomad-server
    relabel_configs:
      - source_labels: [__meta_consul_tags]
        regex: .*nomad-server.*
        action: keep
      - source_labels: [__meta_consul_service]
        target_label: job
      - source_labels: [__meta_consul_node]
        target_label: instance
    metrics_path: '/v1/metrics'
    params:
      format: ['prometheus']

  # Scrape Nomad clients
  - job_name: 'nomad-clients'
    consul_sd_configs:
      - server: '{{ env "CONSUL_HTTP_ADDR" }}'
        services: []
        tags:
          - nomad-client
    relabel_configs:
      - source_labels: [__meta_consul_tags]
        regex: .*nomad-client.*
        action: keep
      - source_labels: [__meta_consul_service]
        target_label: job
      - source_labels: [__meta_consul_node]
        target_label: instance
    metrics_path: '/v1/metrics'
    params:
      format: ['prometheus']

  # Scrape Node Exporter
  - job_name: 'node-exporter'
    consul_sd_configs:
      - server: '{{ env "CONSUL_HTTP_ADDR" }}'
        services: ['node-exporter']
    relabel_configs:
      - source_labels: [__meta_consul_service]
        target_label: job
      - source_labels: [__meta_consul_node]
        target_label: instance

  # Auto-discover services registered in Consul
  - job_name: 'consul-services'
    consul_sd_configs:
      - server: '{{ env "CONSUL_HTTP_ADDR" }}'
        services: []
    relabel_configs:
      - source_labels: [__meta_consul_tags]
        regex: .*metrics.*
        action: keep
      - source_labels: [__meta_consul_service]
        target_label: job
      - source_labels: [__meta_consul_node]
        target_label: instance
EOH
        destination = "local/prometheus.yml"
      }

      template {
        data = <<EOH
groups:
  - name: consul
    rules:
      - alert: ConsulServiceHealthcheckFailed
        expr: consul_health_service_status{status!="passing"} == 1
        for: 0m
        labels:
          severity: critical
        annotations:
          summary: "Consul service healthcheck failed (instance {{ $labels.instance }})"
          description: "Service: `{{ $labels.service_name }}` Healthcheck: `{{ $labels.service_id }}`"

      - alert: ConsulMissingMasterNode
        expr: consul_raft_peers < 3
        for: 0m
        labels:
          severity: critical
        annotations:
          summary: "Consul missing master node (instance {{ $labels.instance }})"
          description: "Numbers of consul raft peers should be 3, in order to preserve quorum."

      - alert: ConsulAgentUnhealthy
        expr: consul_health_node_status{status!="passing"} == 1
        for: 0m
        labels:
          severity: critical
        annotations:
          summary: "Consul agent unhealthy (instance {{ $labels.instance }})"
          description: "A Consul agent is unhealthy"
EOH
        destination = "local/consul_rules.yml"
      }

      template {
        data = <<EOH
groups:
  - name: nomad
    rules:
      - alert: NomadJobFailed
        expr: nomad_nomad_job_summary_failed > 0
        for: 0m
        labels:
          severity: critical
        annotations:
          summary: "Nomad job failed (instance {{ $labels.instance }})"
          description: "Job {{ $labels.job }} failed"

      - alert: NomadJobQueued
        expr: nomad_nomad_job_summary_queued > 0
        for: 2m
        labels:
          severity: warning
        annotations:
          summary: "Nomad job queued (instance {{ $labels.instance }})"
          description: "Job {{ $labels.job }} queued"

      - alert: NomadJobLost
        expr: nomad_nomad_job_summary_lost > 0
        for: 0m
        labels:
          severity: critical
        annotations:
          summary: "Nomad job lost (instance {{ $labels.instance }})"
          description: "Job {{ $labels.job }} lost"

      - alert: NomadNodeDown
        expr: up{job="nomad-servers"} == 0
        for: 0m
        labels:
          severity: critical
        annotations:
          summary: "Nomad node down (instance {{ $labels.instance }})"
          description: "Nomad node is down"
EOH
        destination = "local/nomad_rules.yml"
      }

      resources {
        cpu    = 500
        memory = 1024
      }

      env {
        CONSUL_HTTP_ADDR = "${CONSUL_HTTP_ADDR}"
      }
    }
  }
}