# Nomad Client instances (2 clients)
resource "google_compute_instance" "nomad_clients" {
  count        = 2
  name         = "nomad-client-${count.index + 1}"
  machine_type = var.machine_type_client
  zone         = var.zone

  tags = ["hashistack", "nomad-client"]

  boot_disk {
    initialize_params {
      image = var.use_hcp_packer ? data.hcp_packer_artifact.hashistack_client[0].external_identifier : "ubuntu-os-cloud/ubuntu-2204-lts"
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
      
      # Set environment variables for the configuration script
      export CONSUL_DATACENTER="${var.consul_datacenter}"
      export NOMAD_DATACENTER="${var.nomad_datacenter}"
      export CONSUL_TOKEN="${random_uuid.nomad_client_token.result}"
      export CONSUL_ENCRYPT_KEY="${base64encode(random_string.consul_encrypt_key.result)}"
      export NOMAD_ENCRYPT_KEY="${base64encode(random_string.nomad_encrypt_key.result)}"
      export CONSUL_LICENSE="${var.consul_license}"
      export NOMAD_LICENSE="${var.nomad_license}"
      export PROJECT_ID="${var.project_id}"
      export CONSUL_LOG_LEVEL="${var.consul_log_level}"
      export NOMAD_LOG_LEVEL="${var.nomad_log_level}"
      export ENABLE_ACLS="${var.enable_acls}"
      
      # Install and configure HashiStack (simplified client setup)
      if [ "${var.use_hcp_packer}" = "true" ]; then
        echo "Using custom Packer image"
        /opt/hashistack/scripts/configure-client.sh
      else
        echo "Installing HashiStack on base Ubuntu"
        
        # Install dependencies and HashiStack (same as server but client config)
        apt-get update && apt-get install -y unzip curl jq docker.io
        systemctl enable --now docker
        usermod -aG docker ubuntu
        
        # Create directories and users
        mkdir -p /opt/{consul,nomad}/{bin,data,config,logs}
        useradd --system --home /opt/consul --shell /bin/false consul || true
        useradd --system --home /opt/nomad --shell /bin/false nomad || true
        chown -R consul:consul /opt/consul && chown -R nomad:nomad /opt/nomad
        
        # Download binaries
        cd /tmp
        curl -fsSL https://releases.hashicorp.com/consul/${var.consul_version}/consul_${var.consul_version}_linux_amd64.zip -o consul.zip && unzip consul.zip && mv consul /opt/consul/bin/ && rm consul.zip
        curl -fsSL https://releases.hashicorp.com/nomad/${var.nomad_version}/nomad_${var.nomad_version}_linux_amd64.zip -o nomad.zip && unzip nomad.zip && mv nomad /opt/nomad/bin/ && rm nomad.zip
        chown consul:consul /opt/consul/bin/consul && chown nomad:nomad /opt/nomad/bin/nomad
        chmod +x /opt/{consul,nomad}/bin/*
        
        # Create systemd services (simplified)
        cat > /etc/systemd/system/consul.service << CONSULSERVICE
[Unit]
Description=Consul
After=network-online.target
[Service]
Type=notify
User=consul
ExecStart=/opt/consul/bin/consul agent -config-dir=/opt/consul/config/
Restart=on-failure
[Install]
WantedBy=multi-user.target
CONSULSERVICE
        
        cat > /etc/systemd/system/nomad.service << NOMADSERVICE
[Unit]
Description=Nomad
After=network-online.target consul.service
[Service]
Type=exec
User=nomad
ExecStart=/opt/nomad/bin/nomad agent -config=/opt/nomad/config/nomad.hcl
Restart=on-failure
[Install]
WantedBy=multi-user.target
NOMADSERVICE
        systemctl daemon-reload
      fi
      
      # Common configuration
      INSTANCE_NAME=$(curl -s "http://metadata.google.internal/computeMetadata/v1/instance/name" -H "Metadata-Flavor: Google")
      PRIVATE_IP=$(curl -s "http://metadata.google.internal/computeMetadata/v1/instance/network-interfaces/0/ip" -H "Metadata-Flavor: Google")
      
      # Create license files
      [ -n "$CONSUL_LICENSE" ] && echo "$CONSUL_LICENSE" > /opt/consul/consul.lic && chown consul:consul /opt/consul/consul.lic && chmod 600 /opt/consul/consul.lic
      [ -n "$NOMAD_LICENSE" ] && echo "$NOMAD_LICENSE" > /opt/nomad/nomad.lic && chown nomad:nomad /opt/nomad/nomad.lic && chmod 600 /opt/nomad/nomad.lic
      
      # Client configurations
      cat > /opt/consul/config/consul.hcl << CONSULCONFIG
datacenter = "$${CONSUL_DATACENTER:-dc1}"
data_dir = "/opt/consul/data"
log_level = "$${CONSUL_LOG_LEVEL:-INFO}"
node_name = "$INSTANCE_NAME"
bind_addr = "$PRIVATE_IP"
client_addr = "0.0.0.0"
retry_join = ["provider=gce project_name=$${PROJECT_ID} tag_value=consul-server"]
connect { enabled = true }
license_path = "/opt/consul/consul.lic"
encrypt = "$CONSUL_ENCRYPT_KEY"
acl = {
  enabled = $${ENABLE_ACLS:-true}
  default_policy = "deny"
  enable_token_persistence = true
  tokens { default = "$${CONSUL_TOKEN}" }
}
ports { grpc = 8502 }
CONSULCONFIG

      cat > /opt/nomad/config/nomad.hcl << NOMADCONFIG
datacenter = "$${NOMAD_DATACENTER:-dc1}"
data_dir = "/opt/nomad/data"
log_level = "$${NOMAD_LOG_LEVEL:-INFO}"
name = "$INSTANCE_NAME"
license_path = "/opt/nomad/nomad.lic"
bind_addr = "$PRIVATE_IP"

client {
  enabled = true
  server_join {
    retry_join = ["provider=gce project_name=$${PROJECT_ID} tag_value=nomad-server"]
  }
  options {
    "driver.raw_exec.enable" = "1"
    "driver.docker.enable" = "1"
  }
  host_volume "docker_sock" {
    path = "/var/run/docker.sock"
    read_only = false
  }
}

consul {
  address = "127.0.0.1:8500"
  server_service_name = "nomad"
  client_service_name = "nomad-client"
  auto_advertise = true
  server_auto_join = true
  client_auto_join = true
  token = "$${CONSUL_TOKEN}"
}

plugin "docker" {
  config {
    volumes { enabled = true }
    allow_privileged = true
  }
}
NOMADCONFIG

      chown consul:consul /opt/consul/config/consul.hcl
      chown nomad:nomad /opt/nomad/config/nomad.hcl
      chmod 640 /opt/{consul,nomad}/config/*.hcl
      
      # Start services
      systemctl enable consul nomad
      systemctl start consul && sleep 5 && systemctl start nomad
      
      echo "HashiStack client configuration complete: $INSTANCE_NAME"
    EOF
  }

  depends_on = [
    google_compute_subnetwork.hashistack_subnet,
    google_compute_instance.nomad_servers
  ]
}