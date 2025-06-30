#!/bin/bash
set -e

# Runtime configuration for HashiStack servers
# Variables provided by Terraform: dc_name, gcp_project, tag, consul_license, nomad_license, bootstrap_token, zone, node_name, nomad_token, nomad_bootstrapper

CONSUL_DIR="/etc/consul.d"
NOMAD_DIR="/etc/nomad.d"

# Get instance metadata
NODE_HOSTNAME=$(curl -H 'Metadata-Flavor:Google' http://metadata.google.internal/computeMetadata/v1/instance/hostname)
PUBLIC_IP=$(curl -H 'Metadata-Flavor:Google' http://metadata.google.internal/computeMetadata/v1/instance/network-interfaces/0/access-configs/0/external-ip)
PRIVATE_IP=$(curl -H 'Metadata-Flavor:Google' http://metadata.google.internal/computeMetadata/v1/instance/network-interfaces/0/ip)

# Template variables
DC="${dc_name}"
CONSUL_LICENSE="${consul_license}"
NOMAD_LICENSE="${nomad_license}"

echo "==> Configuring HashiStack server: ${node_name}"

# Create directories if they don't exist
sudo mkdir -p $CONSUL_DIR $NOMAD_DIR /opt/consul/audit /opt/nomad

# Install Consul and Nomad if not present (for base images)
if ! command -v consul &> /dev/null; then
    echo "==> Installing Consul and Nomad..."
    
    # Install prerequisites
    sudo apt-get update
    sudo apt-get install -y unzip curl gnupg dnsutils lsb-release
    
    # Install Docker
    sudo mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    sudo apt-get update
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
    
    # Install Consul
    CONSUL_VERSION="1.17.0+ent"
    curl -s -O https://releases.hashicorp.com/consul/$${CONSUL_VERSION}/consul_$${CONSUL_VERSION}_linux_amd64.zip
    unzip -o consul_$${CONSUL_VERSION}_linux_amd64.zip
    sudo mv consul /usr/bin/
    sudo chmod +x /usr/bin/consul
    rm -f consul_$${CONSUL_VERSION}_linux_amd64.zip
    
    # Install Nomad  
    NOMAD_VERSION="1.7.2+ent"
    curl -s -O https://releases.hashicorp.com/nomad/$${NOMAD_VERSION}/nomad_$${NOMAD_VERSION}_linux_amd64.zip
    unzip -o nomad_$${NOMAD_VERSION}_linux_amd64.zip
    sudo mv nomad /usr/bin/
    sudo chmod +x /usr/bin/nomad
    rm -f nomad_$${NOMAD_VERSION}_linux_amd64.zip
    
    # Create users
    sudo useradd --system --home $CONSUL_DIR --shell /bin/false consul || true
    sudo useradd --system --home $NOMAD_DIR --shell /bin/false nomad || true
    
    # Set permissions
    sudo chown -R consul:consul /opt/consul
    sudo chown -R nomad:nomad /opt/nomad
    
    # Generate TLS CA and encryption key
    sudo mkdir -p $CONSUL_DIR/tls
    consul tls ca create
    sudo mv consul-agent-ca*.pem $CONSUL_DIR/tls/
    consul keygen | sudo tee $CONSUL_DIR/keygen.out
fi

# Enterprise Licenses
echo "$CONSUL_LICENSE" | sudo tee $CONSUL_DIR/license.hclic > /dev/null
echo "$NOMAD_LICENSE" | sudo tee $NOMAD_DIR/license.hclic > /dev/null

# Generate server certificates
echo "==> Generating server certificates"
consul tls cert create -server -dc $DC \
    -ca "$CONSUL_DIR"/tls/consul-agent-ca.pem \
    -key "$CONSUL_DIR"/tls/consul-agent-ca-key.pem
sudo mv "$DC"-server-consul-*.pem "$CONSUL_DIR"/tls/

# Consul server configuration
echo "==> Generating Consul configuration"
sudo tee $CONSUL_DIR/consul.hcl > /dev/null <<EOF
datacenter = "$DC"
data_dir = "/opt/consul"
node_name = "${node_name}"
node_meta = {
  hostname = "$(hostname)"
  gcp_instance = "$(curl "http://metadata.google.internal/computeMetadata/v1/instance/name" -H "Metadata-Flavor: Google")"
  gcp_zone = "$(curl -H "Metadata-Flavor: Google" "http://metadata.google.internal/computeMetadata/v1/instance/zone" | awk -F / '{print $NF}')"
}
encrypt = "$(cat $CONSUL_DIR/keygen.out)"
retry_join = ["provider=gce project_name=${gcp_project} tag_value=${tag} zone_pattern=\"${zone}-[a-z]\""]
license_path = "$CONSUL_DIR/license.hclic"
log_level = "INFO"

server = true
bootstrap_expect = 3
ui = true
client_addr = "0.0.0.0"
bind_addr = "$PRIVATE_IP"

connect {
  enabled = true
}

tls {
   defaults {
      ca_file = "$CONSUL_DIR/tls/consul-agent-ca.pem"
      cert_file = "$CONSUL_DIR/tls/$DC-server-consul-0.pem"
      key_file = "/etc/consul.d/tls/$DC-server-consul-0-key.pem"
      verify_incoming = false
      verify_outgoing = true
      verify_server_hostname = false
   }
   internal_rpc {
      verify_server_hostname = true
   }
}

auto_encrypt {
  allow_tls = true
}

acl = {
  enabled = true
  default_policy = "deny"
  enable_token_persistence = true
  tokens = {
    initial_management = "${bootstrap_token}"
    agent = "${bootstrap_token}"
    dns = "${bootstrap_token}"
  }
}

audit {
  enabled = true
  sink "${dc_name}_sink" {
    type   = "file"
    format = "json"
    path   = "/opt/consul/audit/audit.json"
    delivery_guarantee = "best-effort"
    rotate_duration = "24h"
    rotate_max_files = 15
    rotate_bytes = 25165824
    mode = "644"
  }
}

ports {
  https = 8501
  grpc = 8502
  grpc_tls = 8503
}
EOF

# ----------------------------------
echo "==> Generating Nomad configs"

sudo tee $NOMAD_DIR/nomad.hcl > /dev/null <<EOF
datacenter = "$DC"
data_dir = "/opt/nomad"
acl  {
  enabled = true
}
consul {
  token = "${bootstrap_token}"
  enabled = true

  service_identity {
    aud = ["consul.io"]
    ttl = "1h"
  }

  task_identity {
    aud = ["consul.io"]
    ttl = "1h"
  }
}
EOF

sudo tee $NOMAD_DIR/server.hcl > /dev/null <<EOF
server {
  enabled = true
  bootstrap_expect = 3
  server_join {
    retry_join = ["provider=gce project_name=${gcp_project} tag_value=${tag}"]
  }
  license_path = "$NOMAD_DIR/license.hclic"
}
EOF

sudo tee $NOMAD_DIR/client.hcl > /dev/null <<EOF
client {
  enabled = false
}
EOF

sudo tee $NOMAD_DIR/nomad_bootstrap > /dev/null <<EOF
${nomad_token}
EOF

# Create systemd services
echo "==> Creating systemd services"
sudo tee /usr/lib/systemd/system/consul.service > /dev/null <<EOF
[Unit]
Description="HashiCorp Consul - A service mesh solution"
Documentation=https://www.consul.io/
Requires=network-online.target
After=network-online.target
ConditionFileNotEmpty=$CONSUL_DIR/consul.hcl

[Service]
Type=notify
User=consul
Group=consul
ExecStart=/usr/bin/consul agent -config-dir="$CONSUL_DIR"/
ExecReload=/bin/kill --signal HUP \$MAINPID
KillMode=process
KillSignal=SIGTERM
Restart=on-failure
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF

sudo tee /usr/lib/systemd/system/nomad.service > /dev/null <<EOF
[Unit]
Description=Nomad
Documentation=https://www.nomadproject.io/docs/
Wants=network-online.target
After=network-online.target

[Service]
User=nomad
Group=nomad
ExecReload=/bin/kill -HUP \$MAINPID
ExecStart=/usr/bin/nomad agent -config $NOMAD_DIR
KillMode=process
KillSignal=SIGINT
LimitNOFILE=65536
LimitNPROC=infinity
Restart=on-failure
RestartSec=2
TasksMax=infinity
OOMScoreAdjust=-1000

[Install]
WantedBy=multi-user.target
EOF

# Set permissions
echo "==> Setting permissions"
sudo chown -R consul:consul "$CONSUL_DIR"
sudo chown -R nomad:nomad "$NOMAD_DIR"

# Start services
echo "==> Starting services"
sudo systemctl daemon-reload
sudo systemctl enable consul nomad
sudo systemctl start consul
sleep 10
sudo systemctl start nomad

# We select the last node as the Nomad bootstrapper
%{ if nomad_bootstrapper }
# But wait for the Nomad leader to be elected
HTTP_STATUS=$(curl -s -o /dev/null -w "%%{http_code}" http://localhost:4646/v1/status/leader)
counter=0
while [ $HTTP_STATUS -ne 200 ]; do
  echo "==> Waiting for Nomad to start..."
  sleep 10
  HTTP_STATUS=$(curl -s -o /dev/null -w "%%{http_code}" http://localhost:4646/v1/status/leader)
  counter=$((counter+1))
  if [ $counter -eq 10 ]; then
    echo "==> Nomad failed to start. Exiting..."
    break
  fi
done
echo "==> Bootstrap Nomad..."
# sleep 20
nomad acl bootstrap $NOMAD_DIR/nomad_bootstrap
%{ endif }

echo "==> HashiStack server configuration complete: ${node_name}"