# Nomad Client Configuration with Consul Integration
datacenter = "${NOMAD_DATACENTER:-dc1}"
data_dir = "/opt/nomad/data"
log_level = "${NOMAD_LOG_LEVEL:-INFO}"
name = "$INSTANCE_NAME"

# Enterprise License
license_path = "/opt/nomad/nomad.lic"

# Client Configuration
client {
  enabled = true
  
  server_join {
    retry_join = ["provider=gce project_name=${PROJECT_ID} tag_value=nomad-server"]
    retry_max = 3
    retry_interval = "15s"
  }
  
  # Node class and metadata
  node_class = "compute"
  meta {
    "node-type" = "worker"
    "os" = "linux"
    "arch" = "amd64"
  }
  
  # Driver options
  options {
    "driver.raw_exec.enable" = "1"
    "driver.docker.enable" = "1"
    "driver.java.enable" = "1"
    "driver.exec.enable" = "1"
    "user.checked_drivers" = "docker,exec,java,raw_exec"
  }
  
  # Host volumes for persistent storage
  host_volume "prometheus_data" {
    path      = "/opt/nomad/host_volumes/prometheus_data"
    read_only = false
  }
  
  host_volume "grafana_data" {
    path      = "/opt/nomad/host_volumes/grafana_data"
    read_only = false
  }
  
  host_volume "docker_sock" {
    path = "/var/run/docker.sock"
    read_only = false
  }
  
  host_volume "consul_data" {
    path = "/opt/consul/data"
    read_only = false
  }
  
  # Resource settings
  reserved {
    cpu    = 500  # MHz
    memory = 512  # MB
    disk   = 1024 # MB
  }
  
  # Network configuration
  network_interface = "eth0"
  
  # Service registration with Consul
  consul_service_name = "nomad-client"
}

bind_addr = "$PRIVATE_IP"

# Consul Integration - Critical for Service Discovery
consul {
  # Consul connection settings
  address = "127.0.0.1:8500"
  server_service_name = "nomad-server"
  client_service_name = "nomad-client"
  
  # Auto-advertise services
  auto_advertise = true
  server_auto_join = true
  client_auto_join = true
  
  # ACL token for Consul API access
  token = "${CONSUL_TOKEN}"
  
  # Service registration settings
  tags = ["nomad-client", "worker"]
  
  # Enable Consul Connect integration
  client_http_check_name = "Nomad Client HTTP"
  
  # Consul Connect
  ca_file = "/opt/consul/tls/consul-agent-ca.pem"
  cert_file = "/opt/consul/tls/consul-agent.pem"  
  key_file = "/opt/consul/tls/consul-agent-key.pem"
  verify_ssl = false
  
  # Service mesh integration
  namespace = "default"
}

# Telemetry for monitoring
telemetry {
  collection_interval = "1s"
  disable_hostname = true
  prometheus_metrics = true
  publish_allocation_metrics = true
  publish_node_metrics = true
  statsd_address = "127.0.0.1:8125"
}

# Docker Plugin Configuration
plugin "docker" {
  config {
    # Enable volumes
    volumes {
      enabled = true
    }
    
    # Allow privileged containers (needed for some workloads)
    allow_privileged = true
    
    # Enable caps
    allow_caps = ["ALL"]
    
    # Docker daemon settings
    endpoint = "unix:///var/run/docker.sock"
    
    # Image pull settings
    pull_activity_timeout = "10m"
    
    # Resource limits
    gc {
      image = true
      image_delay = "3m"
      container = true
      container_delay = "3m"
      dangling_containers {
        enabled = true
        dry_run = false
        period = "5m"
        creation_grace = "5m"
      }
    }
  }
}

# Java Plugin Configuration  
plugin "java" {
  config {
    # Enable the Java driver
    enabled = true
  }
}

# Raw Exec Plugin Configuration
plugin "raw_exec" {
  config {
    # Enable raw exec (use with caution)
    enabled = true
  }
}

# TLS Configuration
tls {
  http = false
  rpc = false
  ca_file = "/opt/nomad/tls/nomad-agent-ca.pem"
  cert_file = "/opt/nomad/tls/nomad-agent.pem"
  key_file = "/opt/nomad/tls/nomad-agent-key.pem"
  verify_server_hostname = false
  verify_https_client = false
}

# Log configuration
log_json = true
enable_syslog = false

# Plugin configuration for CSI
plugin_dir = "/opt/nomad/plugins"

# Service registration
service {
  name = "nomad-client"
  tags = ["nomad", "client", "worker"]
  port = 4646
  check {
    name = "Nomad Client HTTP"
    http = "http://localhost:4646/v1/status/leader"
    interval = "10s"
    timeout = "3s"
  }
}