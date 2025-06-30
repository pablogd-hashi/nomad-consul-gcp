# Nomad/Consul Server instances (3 servers total)
resource "google_compute_instance" "nomad_servers" {
  count        = 3
  name         = "nomad-server-${count.index + 1}"
  machine_type = var.machine_type_server
  zone         = var.zone

  tags = ["hashistack", "nomad-server", "consul-server"]

  boot_disk {
    initialize_params {
      image = var.use_hcp_packer ? data.hcp_packer_artifact.hashistack_server[0].external_identifier : "global/images/hashistack-server-20250630053648"
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
    email  = var.gcp_sa
    scopes = ["cloud-platform"]
  }

  metadata = {
    ssh-keys = "ubuntu:${var.ssh_public_key}"
    startup-script = <<-EOF
      #!/bin/bash
      set -e
      
      # Set environment variables for the configuration script
      export CONSUL_DATACENTER="${var.consul_datacenter}"
      export NOMAD_DATACENTER="${var.nomad_datacenter}"
      export CONSUL_MASTER_TOKEN="${random_uuid.consul_master_token.result}"
      export NOMAD_CONSUL_TOKEN="${random_uuid.nomad_server_token.result}"
      export NOMAD_SERVER_TOKEN="${random_uuid.nomad_server_token.result}"
      export CONSUL_ENCRYPT_KEY="${base64encode(random_string.consul_encrypt_key.result)}"
      export NOMAD_ENCRYPT_KEY="${base64encode(random_string.nomad_encrypt_key.result)}"
      export CONSUL_LICENSE="${var.consul_license}"
      export NOMAD_LICENSE="${var.nomad_license}"
      export SERVER_COUNT="3"
      export PROJECT_ID="${var.project_id}"
      export CONSUL_LOG_LEVEL="${var.consul_log_level}"
      export NOMAD_LOG_LEVEL="${var.nomad_log_level}"
      export ENABLE_ACLS="${var.enable_acls}"
      
      # Install and configure HashiStack
      if [ "${var.use_hcp_packer}" = "true" ]; then
        echo "Using custom Packer image with pre-installed HashiStack"
        /opt/hashistack/scripts/configure-server.sh
      else
        echo "Installing HashiStack on base Ubuntu image"
        
        # Update system and install dependencies
        apt-get update
        apt-get install -y unzip curl jq docker.io docker-compose
        
        # Start and enable Docker
        systemctl start docker
        systemctl enable docker
        usermod -aG docker ubuntu
        
        # Create directories
        mkdir -p /opt/consul/{bin,data,config,logs}
        mkdir -p /opt/nomad/{bin,data,config,logs}
        mkdir -p /opt/hashistack/scripts
        
        # Create users
        useradd --system --home /opt/consul --shell /bin/false consul || true
        useradd --system --home /opt/nomad --shell /bin/false nomad || true
        
        # Set permissions
        chown -R consul:consul /opt/consul
        chown -R nomad:nomad /opt/nomad
        
        # Download and install Consul
        cd /tmp
        curl -fsSL https://releases.hashicorp.com/consul/${var.consul_version}/consul_${var.consul_version}_linux_amd64.zip -o consul.zip
        unzip consul.zip
        mv consul /opt/consul/bin/
        chown consul:consul /opt/consul/bin/consul
        chmod +x /opt/consul/bin/consul
        rm consul.zip
        
        # Download and install Nomad
        curl -fsSL https://releases.hashicorp.com/nomad/${var.nomad_version}/nomad_${var.nomad_version}_linux_amd64.zip -o nomad.zip
        unzip nomad.zip
        mv nomad /opt/nomad/bin/
        chown nomad:nomad /opt/nomad/bin/nomad
        chmod +x /opt/nomad/bin/nomad
        rm nomad.zip
        
        # Create systemd service files
        cat > /etc/systemd/system/consul.service << 'CONSUL_SERVICE'
[Unit]
Description=Consul
Documentation=https://www.consul.io/
Requires=network-online.target
After=network-online.target
ConditionFileNotEmpty=/opt/consul/config/consul.hcl

[Service]
Type=notify
User=consul
Group=consul
ExecStart=/opt/consul/bin/consul agent -config-dir=/opt/consul/config/
ExecReload=/bin/kill -HUP $MAINPID
KillMode=process
Restart=on-failure
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
CONSUL_SERVICE

        cat > /etc/systemd/system/nomad.service << 'NOMAD_SERVICE'
[Unit]
Description=Nomad
Documentation=https://www.nomadproject.io/
Requires=network-online.target
After=network-online.target consul.service
ConditionFileNotEmpty=/opt/nomad/config/nomad.hcl

[Service]
Type=exec
User=nomad
Group=nomad
ExecStart=/opt/nomad/bin/nomad agent -config=/opt/nomad/config/nomad.hcl
ExecReload=/bin/kill -HUP $MAINPID
KillMode=process
Restart=on-failure
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
NOMAD_SERVICE

        systemctl daemon-reload
      fi
      
      # Common configuration (works for both Packer and base images)
      # Get instance metadata
      INSTANCE_NAME=$(curl -s "http://metadata.google.internal/computeMetadata/v1/instance/name" -H "Metadata-Flavor: Google")
      PRIVATE_IP=$(curl -s "http://metadata.google.internal/computeMetadata/v1/instance/network-interfaces/0/ip" -H "Metadata-Flavor: Google")
      
      echo "Configuring HashiStack server: $INSTANCE_NAME"
      
      # Create license files
      if [ -n "$CONSUL_LICENSE" ]; then
        echo "$CONSUL_LICENSE" > /opt/consul/consul.lic
        chown consul:consul /opt/consul/consul.lic
        chmod 600 /opt/consul/consul.lic
      fi
      
      if [ -n "$NOMAD_LICENSE" ]; then
        echo "$NOMAD_LICENSE" > /opt/nomad/nomad.lic
        chown nomad:nomad /opt/nomad/nomad.lic
        chmod 600 /opt/nomad/nomad.lic
      fi
      
      # Create Consul configuration
      cat > /opt/consul/config/consul.hcl << CONSUL_CONFIG
datacenter = "$${CONSUL_DATACENTER:-dc1}"
data_dir = "/opt/consul/data"
log_level = "$${CONSUL_LOG_LEVEL:-INFO}"
node_name = "$INSTANCE_NAME"
server = true
bootstrap_expect = $${SERVER_COUNT:-3}
retry_join = ["provider=gce project_name=$${PROJECT_ID} tag_value=consul-server"]
bind_addr = "$PRIVATE_IP"
client_addr = "0.0.0.0"

ui_config {
  enabled = true
}

connect {
  enabled = true
}

license_path = "/opt/consul/consul.lic"
encrypt = "$CONSUL_ENCRYPT_KEY"

acl = {
  enabled = $${ENABLE_ACLS:-true}
  default_policy = "deny"
  enable_token_persistence = true
  tokens {
    initial_management = "$${CONSUL_MASTER_TOKEN}"
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

      # Create Nomad configuration
      cat > /opt/nomad/config/nomad.hcl << NOMAD_CONFIG
datacenter = "$${NOMAD_DATACENTER:-dc1}"
data_dir = "/opt/nomad/data"
log_level = "$${NOMAD_LOG_LEVEL:-INFO}"
name = "$INSTANCE_NAME"

license_path = "/opt/nomad/nomad.lic"

server {
  enabled = true
  bootstrap_expect = $${SERVER_COUNT:-3}
  
  server_join {
    retry_join = ["provider=gce project_name=$${PROJECT_ID} tag_value=nomad-server"]
    retry_max = 3
    retry_interval = "15s"
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
  token = "$${NOMAD_CONSUL_TOKEN}"
}

acl {
  enabled = $${ENABLE_ACLS:-true}
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
NOMAD_CONFIG

      # Set permissions
      chown consul:consul /opt/consul/config/consul.hcl
      chown nomad:nomad /opt/nomad/config/nomad.hcl
      chmod 640 /opt/consul/config/consul.hcl
      chmod 640 /opt/nomad/config/nomad.hcl
      
      # Start services
      systemctl enable consul nomad
      systemctl start consul
      sleep 10
      systemctl start nomad
      
      echo "HashiStack server configuration complete: $INSTANCE_NAME"
      
      # Bootstrap ACLs on first server
      SERVER_IDX="${count.index + 1}"
      if [ "$SERVER_IDX" = "1" ] && [ "${var.enable_acls}" = "true" ]; then
        echo "Bootstrapping ACLs on server 1..."
        sleep 60
        export CONSUL_HTTP_TOKEN="${random_uuid.consul_master_token.result}"
        export NOMAD_TOKEN="${random_uuid.nomad_server_token.result}"
        nomad acl bootstrap -initial-management-token="${random_uuid.nomad_server_token.result}" || echo "ACL bootstrap failed or already done"
      fi
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