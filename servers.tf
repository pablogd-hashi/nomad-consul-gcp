# Nomad/Consul Server instances (3 servers total)
resource "google_compute_instance" "nomad_servers" {
  count        = 3
  name         = "nomad-server-${count.index + 1}"
  machine_type = var.machine_type_server
  zone         = var.zone

  tags = ["hashistack", "nomad-server", "consul-server"]

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2204-lts"
      size  = 50
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
    email  = data.google_service_account.existing_sa.email
    scopes = ["cloud-platform"]
  }

  metadata = {
    ssh-keys = "ubuntu:${var.ssh_public_key}"
    startup-script = <<-EOF
      #!/bin/bash
      set -e
      
      # Variables from Terraform
      CONSUL_VER="${var.consul_version}"
      NOMAD_VER="${var.nomad_version}"
      CONSUL_DC="${var.consul_datacenter}"
      NOMAD_DC="${var.nomad_datacenter}"
      CONSUL_KEY="${base64encode(random_id.consul_encrypt.hex)}"
      CONSUL_TOKEN="${random_uuid.consul_master_token.result}"
      NOMAD_CONSUL_TOKEN="${random_uuid.nomad_consul_token.result}"
      NOMAD_SERVER_TOKEN="${random_uuid.nomad_server_token.result}"
      CONSUL_LIC="${var.consul_license}"
      NOMAD_LIC="${var.nomad_license}"
      SERVER_IDX="${count.index + 1}"
      SERVER_CNT="3"
      CA_CERT_B64="${base64encode(tls_self_signed_cert.ca.cert_pem)}"
      CA_KEY_B64="${base64encode(tls_private_key.ca.private_key_pem)}"
      PROJECT="${var.project_id}"
      
      # Get instance metadata
      INSTANCE_NAME=$(curl -s "http://metadata.google.internal/computeMetadata/v1/instance/name" -H "Metadata-Flavor: Google")
      PRIVATE_IP=$(curl -s "http://metadata.google.internal/computeMetadata/v1/instance/network-interfaces/0/ip" -H "Metadata-Flavor: Google")
      
      echo "Starting server setup: $${INSTANCE_NAME} (Server $${SERVER_IDX})"
      
      # Update system
      apt-get update
      apt-get install -y unzip curl jq docker.io docker-compose
      
      # Start Docker
      systemctl start docker
      systemctl enable docker
      usermod -aG docker ubuntu
      
      # Create directories
      mkdir -p /opt/consul/{bin,data,config,logs}
      mkdir -p /opt/nomad/{bin,data,config,logs}
      mkdir -p /etc/ssl/hashistack
      
      # Download and install software
      cd /tmp
      
      # Download Consul (hardcoded version for now)
      wget "https://releases.hashicorp.com/consul/1.17.0+ent/consul_1.17.0+ent_linux_amd64.zip"
      unzip "consul_1.17.0+ent_linux_amd64.zip"
      mv consul /opt/consul/bin/
      chmod +x /opt/consul/bin/consul
      ln -s /opt/consul/bin/consul /usr/local/bin/consul
      
      # Download Nomad (hardcoded version for now)
      wget "https://releases.hashicorp.com/nomad/1.7.2+ent/nomad_1.7.2+ent_linux_amd64.zip"
      unzip "nomad_1.7.2+ent_linux_amd64.zip"
      mv nomad /opt/nomad/bin/
      chmod +x /opt/nomad/bin/nomad
      ln -s /opt/nomad/bin/nomad /usr/local/bin/nomad
      
      # Setup certificates
      echo "$${CA_CERT_B64}" | base64 -d > /etc/ssl/hashistack/ca.pem
      echo "$${CA_KEY_B64}" | base64 -d > /etc/ssl/hashistack/ca-key.pem
      chmod 600 /etc/ssl/hashistack/ca-key.pem
      
      # Create users
      useradd --system --home /etc/consul.d --shell /bin/false consul
      useradd --system --home /etc/nomad.d --shell /bin/false nomad
      
      # Set ownership
      chown -R consul:consul /opt/consul
      chown -R nomad:nomad /opt/nomad
      
      # Create Consul config
      cat > /opt/consul/config/consul.hcl << 'CONSUL_EOF'
datacenter = "$${CONSUL_DC}"
data_dir = "/opt/consul/data"
log_level = "INFO"
node_name = "$${INSTANCE_NAME}"
server = true
bootstrap_expect = $${SERVER_CNT}
retry_join = ["provider=gce project_name=$${PROJECT} tag_value=consul-server"]
bind_addr = "$${PRIVATE_IP}"
client_addr = "0.0.0.0"

ui_config {
  enabled = true
}

connect {
  enabled = true
}

enterprise {
  license = "$${CONSUL_LIC}"
}

encrypt = "$${CONSUL_KEY}"

acl = {
  enabled = true
  default_policy = "deny"
  enable_token_persistence = true
  tokens {
    initial_management = "$${CONSUL_TOKEN}"
  }
}

telemetry {
  prometheus_retention_time = "24h"
  disable_hostname = true
}

ports {
  grpc = 8502
}
CONSUL_EOF
      
      # Create Nomad config
      cat > /opt/nomad/config/nomad.hcl << 'NOMAD_EOF'
datacenter = "$${NOMAD_DC}"
data_dir = "/opt/nomad/data"
log_level = "INFO"
name = "$${INSTANCE_NAME}"

server {
  enabled = true
  bootstrap_expect = $${SERVER_CNT}
  
  server_join {
    retry_join = ["provider=gce project_name=$${PROJECT} tag_value=nomad-server"]
    retry_max = 3
    retry_interval = "15s"
  }
}

bind_addr = "$${PRIVATE_IP}"

consul {
  address = "127.0.0.1:8500"
  server_service_name = "nomad"
  client_service_name = "nomad-client"
  auto_advertise = true
  server_auto_join = true
  client_auto_join = true
  token = "$${NOMAD_CONSUL_TOKEN}"
}

acl {
  enabled = true
  token_ttl = "30s"
  policy_ttl = "60s"
  role_ttl = "60s"
}

telemetry {
  collection_interval = "1s"
  disable_hostname = true
  prometheus_metrics = true
  publish_allocation_metrics = true
  publish_node_metrics = true
}

ui {
  enabled = true
  consul {
    ui_url = "http://localhost:8500/ui"
  }
}
NOMAD_EOF
      
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
LimitNOFILE=65536

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
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
NOMAD_SVC
      
      # Start services
      systemctl daemon-reload
      systemctl enable consul nomad
      systemctl start consul
      
      sleep 30
      systemctl start nomad
      
      # Bootstrap ACLs on first server
      if [ "$${SERVER_IDX}" = "1" ]; then
        sleep 60
        export CONSUL_HTTP_TOKEN="$${CONSUL_TOKEN}"
        export NOMAD_TOKEN="$${NOMAD_SERVER_TOKEN}"
        nomad acl bootstrap -initial-management-token="$${NOMAD_SERVER_TOKEN}" || true
      fi
      
      echo "Server setup complete: $${INSTANCE_NAME}"
    EOF
  }

  depends_on = [
    google_compute_subnetwork.hashistack_subnet
  ]
}

# Data source to get server private IPs for client configuration
data "google_compute_instance" "nomad_servers" {
  count = 3
  name  = google_compute_instance.nomad_servers[count.index].name
  zone  = var.zone
  
  depends_on = [google_compute_instance.nomad_servers]
}
