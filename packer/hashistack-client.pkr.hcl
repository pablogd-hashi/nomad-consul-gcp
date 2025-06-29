packer {
  required_plugins {
    googlecompute = {
      source  = "github.com/hashicorp/googlecompute"
      version = ">= 1.0.0"
    }
  }
}

# HCP Packer registry configuration
hcp_packer_registry {
  bucket_name = "hashistack-client"
  description = "HashiStack Client images with Consul and Nomad Enterprise"
  
  bucket_labels = {
    "team"        = "platform"
    "environment" = "production"
    "consul"      = var.consul_version
    "nomad"       = var.nomad_version
  }
}

variable "project_id" {
  type        = string
  description = "GCP Project ID"
}

variable "region" {
  type        = string
  description = "GCP Region"
  default     = "us-central1"
}

variable "zone" {
  type        = string
  description = "GCP Zone"
  default     = "us-central1-a"
}

variable "consul_version" {
  type        = string
  description = "Consul version to install"
  default     = "1.20.0+ent"
}

variable "nomad_version" {
  type        = string
  description = "Nomad version to install"
  default     = "1.10.0+ent"
}

variable "image_name" {
  type        = string
  description = "Name for the resulting image"
  default     = "hashistack-client"
}

variable "image_family" {
  type        = string
  description = "Image family name"
  default     = "hashistack-client"
}

variable "machine_type" {
  type        = string
  description = "Machine type for build instance"
  default     = "e2-standard-4"
}

locals {
  timestamp = regex_replace(timestamp(), "[- TZ:]", "")
}

source "googlecompute" "hashistack_client" {
  project_id          = var.project_id
  source_image_family = "ubuntu-2204-lts"
  source_image_project_id = ["ubuntu-os-cloud"]
  zone                = var.zone
  machine_type        = var.machine_type
  
  image_name          = "${var.image_name}-${local.timestamp}"
  image_family        = var.image_family
  image_description   = "HashiStack Client Image with Consul ${var.consul_version} and Nomad ${var.nomad_version}"
  
  disk_size           = 100
  disk_type          = "pd-standard"
  
  ssh_username       = "ubuntu"
  
  tags = ["packer", "hashistack-client"]
  
  metadata = {
    enable-oslogin = "FALSE"
  }
}

build {
  name = "hashistack-client"
  sources = ["source.googlecompute.hashistack_client"]

  # System updates and base packages
  provisioner "shell" {
    inline = [
      "sudo apt-get update",
      "sudo apt-get install -y unzip curl jq docker.io nginx wget",
      "sudo systemctl start docker",
      "sudo systemctl enable docker",
      "sudo usermod -aG docker ubuntu"
    ]
  }

  # Create directory structure
  provisioner "shell" {
    inline = [
      "sudo mkdir -p /opt/consul/{bin,data,config,logs}",
      "sudo mkdir -p /opt/nomad/{bin,data,config,logs}",
      "sudo mkdir -p /opt/nomad/host_volumes/{prometheus_data,grafana_data}",
      "sudo mkdir -p /etc/ssl/hashistack",
      "sudo mkdir -p /opt/hashistack/scripts"
    ]
  }

  # Download and install HashiCorp binaries
  provisioner "shell" {
    inline = [
      "cd /tmp",
      "echo 'Downloading Consul ${var.consul_version}...'",
      "wget -q https://releases.hashicorp.com/consul/${var.consul_version}/consul_${var.consul_version}_linux_amd64.zip",
      "sudo unzip -o consul_${var.consul_version}_linux_amd64.zip -d /opt/consul/bin/",
      "sudo chmod +x /opt/consul/bin/consul",
      "sudo ln -sf /opt/consul/bin/consul /usr/local/bin/consul",
      "rm -f consul_${var.consul_version}_linux_amd64.zip EULA.txt TermsOfEvaluation.txt",
      "",
      "echo 'Downloading Nomad ${var.nomad_version}...'",
      "wget -q https://releases.hashicorp.com/nomad/${var.nomad_version}/nomad_${var.nomad_version}_linux_amd64.zip",
      "sudo unzip -o nomad_${var.nomad_version}_linux_amd64.zip -d /opt/nomad/bin/",
      "sudo chmod +x /opt/nomad/bin/nomad",
      "sudo ln -sf /opt/nomad/bin/nomad /usr/local/bin/nomad",
      "rm -f nomad_${var.nomad_version}_linux_amd64.zip EULA.txt TermsOfEvaluation.txt"
    ]
  }

  # Create system users
  provisioner "shell" {
    inline = [
      "sudo useradd --system --home /etc/consul.d --shell /bin/false consul || true",
      "sudo useradd --system --home /etc/nomad.d --shell /bin/false nomad || true"
    ]
  }

  # Set initial ownership and permissions
  provisioner "shell" {
    inline = [
      "sudo chown -R consul:consul /opt/consul",
      "sudo chown -R nomad:nomad /opt/nomad",
      "sudo chown -R nobody:nogroup /opt/nomad/host_volumes/"
    ]
  }

  # Create systemd service files
  provisioner "file" {
    content = <<-EOF
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
EOF
    destination = "/tmp/consul.service"
  }

  provisioner "file" {
    content = <<-EOF
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
EOF
    destination = "/tmp/nomad.service"
  }

  # Install systemd services
  provisioner "shell" {
    inline = [
      "sudo mv /tmp/consul.service /etc/systemd/system/",
      "sudo mv /tmp/nomad.service /etc/systemd/system/",
      "sudo systemctl daemon-reload"
    ]
  }

  # Create runtime configuration script
  provisioner "file" {
    content = <<-EOF
#!/bin/bash
set -e

# This script configures and starts HashiStack client services with runtime parameters
# Expected environment variables:
# - CONSUL_DATACENTER, NOMAD_DATACENTER
# - CONSUL_LICENSE, NOMAD_LICENSE
# - CONSUL_TOKEN (default token for clients)
# - PROJECT_ID
# - Optional: CONSUL_ENCRYPT_KEY, ENABLE_ACLS

# Get instance metadata
INSTANCE_NAME=$(curl -s "http://metadata.google.internal/computeMetadata/v1/instance/name" -H "Metadata-Flavor: Google")
PRIVATE_IP=$(curl -s "http://metadata.google.internal/computeMetadata/v1/instance/network-interfaces/0/ip" -H "Metadata-Flavor: Google")

echo "Starting HashiStack client configuration: $INSTANCE_NAME"

# Generate Consul encryption key if not provided
if [ -z "$CONSUL_ENCRYPT_KEY" ]; then
  CONSUL_ENCRYPT_KEY=$(/opt/consul/bin/consul keygen)
fi

# Create license files
if [ -n "$CONSUL_LICENSE" ]; then
  echo "$CONSUL_LICENSE" | sudo tee /opt/consul/consul.lic > /dev/null
  sudo chown consul:consul /opt/consul/consul.lic
  sudo chmod 600 /opt/consul/consul.lic
fi

if [ -n "$NOMAD_LICENSE" ]; then
  echo "$NOMAD_LICENSE" | sudo tee /opt/nomad/nomad.lic > /dev/null
  sudo chown nomad:nomad /opt/nomad/nomad.lic
  sudo chmod 600 /opt/nomad/nomad.lic
fi

# Create Consul configuration
sudo tee /opt/consul/config/consul.hcl > /dev/null << CONSUL_CONFIG
datacenter = "\${CONSUL_DATACENTER:-dc1}"
data_dir = "/opt/consul/data"
log_level = "\${CONSUL_LOG_LEVEL:-INFO}"
node_name = "$INSTANCE_NAME"
bind_addr = "$PRIVATE_IP"
client_addr = "0.0.0.0"
retry_join = ["provider=gce project_name=\${PROJECT_ID} tag_value=consul-server"]

connect {
  enabled = true
}

license_path = "/opt/consul/consul.lic"
encrypt = "$CONSUL_ENCRYPT_KEY"

acl = {
  enabled = \${ENABLE_ACLS:-true}
  default_policy = "deny"
  enable_token_persistence = true
  tokens {
    default = "\${CONSUL_TOKEN}"
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
sudo tee /opt/nomad/config/nomad.hcl > /dev/null << NOMAD_CONFIG
datacenter = "\${NOMAD_DATACENTER:-dc1}"
data_dir = "/opt/nomad/data"
log_level = "\${NOMAD_LOG_LEVEL:-INFO}"
name = "$INSTANCE_NAME"

license_path = "/opt/nomad/nomad.lic"

client {
  enabled = true
  
  server_join {
    retry_join = ["provider=gce project_name=\${PROJECT_ID} tag_value=nomad-server"]
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
  token = "\${CONSUL_TOKEN}"
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

# Fix ownership
sudo chown consul:consul /opt/consul/config/consul.hcl
sudo chown nomad:nomad /opt/nomad/config/nomad.hcl

# Start services
sudo systemctl enable consul nomad
sudo systemctl start consul

echo "Waiting for Consul to start..."
sleep 30

sudo systemctl start nomad

echo "Waiting for Nomad to start..."
sleep 30

echo "HashiStack client configuration complete: $INSTANCE_NAME"
echo "Consul status: $(sudo systemctl is-active consul)"
echo "Nomad status: $(sudo systemctl is-active nomad)"
EOF
    destination = "/tmp/configure-client.sh"
  }

  # Install configuration script
  provisioner "shell" {
    inline = [
      "sudo mv /tmp/configure-client.sh /opt/hashistack/scripts/",
      "sudo chmod +x /opt/hashistack/scripts/configure-client.sh"
    ]
  }

  # Verify installation
  provisioner "shell" {
    inline = [
      "echo 'Verifying installations...'",
      "/opt/consul/bin/consul version",
      "/opt/nomad/bin/nomad version",
      "docker --version",
      "nginx -v"
    ]
  }

  # Clean up
  provisioner "shell" {
    inline = [
      "sudo apt-get autoremove -y",
      "sudo apt-get autoclean",
      "sudo rm -rf /tmp/* /var/tmp/*"
    ]
  }

  post-processor "manifest" {
    output = "manifest-client.json"
    strip_path = true
    custom_data = {
      consul_version = var.consul_version
      nomad_version  = var.nomad_version
      image_family   = var.image_family
    }
  }
}