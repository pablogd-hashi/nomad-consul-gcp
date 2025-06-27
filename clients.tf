# Nomad Client instances (2 clients)
resource "google_compute_instance" "nomad_clients" {
  count        = 2
  name         = "nomad-client-${count.index + 1}"
  machine_type = var.machine_type_client
  zone         = var.zone

  tags = ["hashistack", "nomad-client"]

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2204-lts"
      size  = 100
      type  = "pd-standard"
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.hashistack_subnet.id
    access_config {
      # Ephemeral IP
    }
  }

  service_account {
    email  = var.gcp_sa
    scopes = ["cloud-platform"]
  }

  metadata = {
    ssh-keys = "ubuntu:${var.ssh_public_key}"
    startup-script = <<-EOF
      #!/bin/bash
      set -e
      
      # Set variables directly (no template substitution needed)
      CONSUL_DC="${var.consul_datacenter}"
      NOMAD_DC="${var.nomad_datacenter}"
      CONSUL_KEY="${base64encode(random_id.consul_encrypt.hex)}"
      CONSUL_TOKEN="${random_uuid.consul_master_token.result}"
      NOMAD_CLIENT_TOKEN="${random_uuid.nomad_client_token.result}"
      CONSUL_LIC="${var.consul_license}"
      NOMAD_LIC="${var.nomad_license}"
      CLIENT_IDX="${count.index + 1}"
      PROJECT="${var.project_id}"
      
      # Get instance metadata
      INSTANCE_NAME=$(curl -s "http://metadata.google.internal/computeMetadata/v1/instance/name" -H "Metadata-Flavor: Google")
      PRIVATE_IP=$(curl -s "http://metadata.google.internal/computeMetadata/v1/instance/network-interfaces/0/ip" -H "Metadata-Flavor: Google")
      
      echo "Starting client setup: $INSTANCE_NAME"
      
      # Update system
      apt-get update
      apt-get install -y unzip curl jq docker.io nginx
      
      # Start Docker
      systemctl start docker
      systemctl enable docker
      usermod -aG docker ubuntu
      
      # Create directories
      mkdir -p /opt/consul/{bin,data,config,logs}
      mkdir -p /opt/nomad/{bin,data,config,logs}
      mkdir -p /opt/nomad/host_volumes/{prometheus_data,grafana_data}
      mkdir -p /etc/ssl/hashistack
      
      # Download and install software
      cd /tmp
      
      # Download Consul
      echo "Downloading Consul..."
      wget -q "https://releases.hashicorp.com/consul/1.17.0+ent/consul_1.17.0+ent_linux_amd64.zip"
      unzip -o consul_1.17.0+ent_linux_amd64.zip
      mv consul /opt/consul/bin/
      chmod +x /opt/consul/bin/consul
      ln -s /opt/consul/bin/consul /usr/local/bin/consul
      rm -f consul_1.17.0+ent_linux_amd64.zip EULA.txt TermsOfEvaluation.txt
      
      # Download Nomad
      echo "Downloading Nomad..."
      wget -q "https://releases.hashicorp.com/nomad/1.7.2+ent/nomad_1.7.2+ent_linux_amd64.zip"
      unzip -o nomad_1.7.2+ent_linux_amd64.zip
      mv nomad /opt/nomad/bin/
      chmod +x /opt/nomad/bin/nomad
      ln -s /opt/nomad/bin/nomad /usr/local/bin/nomad
      rm -f nomad_1.7.2+ent_linux_amd64.zip EULA.txt TermsOfEvaluation.txt
      
      # Verify installations
      echo "Consul version: $(/opt/consul/bin/consul version)"
      echo "Nomad version: $(/opt/nomad/bin/nomad version)"
      
      # Create users
      useradd --system --home /etc/consul.d --shell /bin/false consul || true
      useradd --system --home /etc/nomad.d --shell /bin/false nomad || true
      
      # Set ownership
      chown -R consul:consul /opt/consul
      chown -R nomad:nomad /opt/nomad
      chown -R nobody:nogroup /opt/nomad/host_volumes/
      
      # Create Consul config - use cat with variables, not heredoc
      cat > /opt/consul/config/consul.hcl << CONSUL_CONFIG
datacenter = "$CONSUL_DC"
data_dir = "/opt/consul/data"
log_level = "INFO"
node_name = "$INSTANCE_NAME"
bind_addr = "$PRIVATE_IP"
client_addr = "0.0.0.0"
retry_join = ["provider=gce project_name=$PROJECT tag_value=consul-server"]

connect {
  enabled = true
}

enterprise {
  license = "$CONSUL_LIC"
}

encrypt = "$CONSUL_KEY"

acl = {
  enabled = true
  default_policy = "deny"
  enable_token_persistence = true
  tokens {
    default = "$CONSUL_TOKEN"
  }
}

telemetry {
  prometheus_retention_time = "24h"
  disable_hostname = true
}

ports {
  grpc = 8502
}
CONSUL_CONFIG
      
      # Create Nomad config
      cat > /opt/nomad/config/nomad.hcl << NOMAD_CONFIG
datacenter = "$NOMAD_DC"
data_dir = "/opt/nomad/data"
log_level = "INFO"
name = "$INSTANCE_NAME"

client {
  enabled = true
  
  server_join {
    retry_join = ["provider=gce project_name=$PROJECT tag_value=nomad-server"]
    retry_max = 3
    retry_interval = "15s"
  }
  
  options {
    "driver.raw_exec.enable" = "1"
    "driver.docker.enable" = "1"
  }
  
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
}

bind_addr = "$PRIVATE_IP"

consul {
  address = "127.0.0.1:8500"
  server_service_name = "nomad"
  client_service_name = "nomad-client"
  auto_advertise = true
  server_auto_join = true
  client_auto_join = true
  token = "$CONSUL_TOKEN"
}

telemetry {
  collection_interval = "1s"
  disable_hostname = true
  prometheus_metrics = true
  publish_allocation_metrics = true
  publish_node_metrics = true
}

plugin "docker" {
  config {
    volumes {
      enabled = true
    }
    allow_privileged = true
  }
}
NOMAD_CONFIG
      
      # Create systemd services
      cat > /etc/systemd/system/consul.service << 'CONSUL_SVC'
[Unit]
Description=Consul
Requires=network-online.target
After=network-online.target

[Service]
Type=notify
User=consul
Group=consul
ExecStart=/opt/consul/bin/consul agent -config-dir=/opt/consul/config/
Restart=on-failure

[Install]
WantedBy=multi-user.target
CONSUL_SVC
      
      cat > /etc/systemd/system/nomad.service << 'NOMAD_SVC'
[Unit]
Description=Nomad
Requires=network-online.target
After=network-online.target consul.service

[Service]
Type=exec
User=nomad
Group=nomad
ExecStart=/opt/nomad/bin/nomad agent -config=/opt/nomad/config/nomad.hcl
Restart=on-failure

[Install]
WantedBy=multi-user.target
NOMAD_SVC
      
      # Start services
      systemctl daemon-reload
      systemctl enable consul nomad
      
      echo "Starting Consul..."
      systemctl start consul
      
      # Wait for Consul to start
      sleep 30
      
      echo "Starting Nomad..."
      systemctl start nomad
      
      echo "Client setup complete: $INSTANCE_NAME"
      echo "Consul status: $(systemctl is-active consul)"
      echo "Nomad status: $(systemctl is-active nomad)"
    EOF
  }

  depends_on = [
    google_compute_subnetwork.hashistack_subnet,
    google_compute_instance.nomad_servers
  ]
}
