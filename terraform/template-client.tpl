#!/bin/bash
set -e

# Runtime configuration for HashiStack clients
# Variables provided by Terraform: dc_name, gcp_project, tag, consul_license, nomad_license, bootstrap_token, zone, node_name, partition

CONSUL_DIR="/etc/consul.d"
NOMAD_DIR="/etc/nomad.d"

# Get instance metadata
INSTANCE_NAME=$(curl -H 'Metadata-Flavor:Google' http://metadata.google.internal/computeMetadata/v1/instance/name)
PUBLIC_IP=$(curl -H 'Metadata-Flavor:Google' http://metadata.google.internal/computeMetadata/v1/instance/network-interfaces/0/access-configs/0/external-ip)
PRIVATE_IP=$(curl -H 'Metadata-Flavor:Google' http://metadata.google.internal/computeMetadata/v1/instance/network-interfaces/0/ip)

# Template variables
DC="${dc_name}"
CONSUL_LICENSE="${consul_license}"
NOMAD_LICENSE="${nomad_license}"

echo "==> Configuring HashiStack client: ${node_name}"

# Create directories
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
    sudo usermod -G docker -a nomad
    
    # Set permissions
    sudo chown -R consul:consul /opt/consul
    sudo chown -R nomad:nomad /opt/nomad
    
    # Generate TLS CA and encryption key
    sudo mkdir -p $CONSUL_DIR/tls
    consul tls ca create
    sudo mv consul-agent-ca*.pem $CONSUL_DIR/tls/
    consul keygen | sudo tee $CONSUL_DIR/keygen.out
    
    # Install CNI plugins
    CNI_PLUGIN_VERSION="v1.5.1"
    curl -L -o cni-plugins.tgz "https://github.com/containernetworking/plugins/releases/download/$CNI_PLUGIN_VERSION/cni-plugins-linux-amd64-$CNI_PLUGIN_VERSION.tgz"
    sudo mkdir -p /opt/cni/bin
    sudo tar -C /opt/cni/bin -xzf cni-plugins.tgz
    rm cni-plugins.tgz
fi

# Enterprise Licenses
echo "$CONSUL_LICENSE" | sudo tee $CONSUL_DIR/license.hclic > /dev/null
echo "$NOMAD_LICENSE" | sudo tee $NOMAD_DIR/license.hclic > /dev/null

# Consul client configuration
echo "==> Generating Consul configuration"
sudo tee $CONSUL_DIR/consul.hcl > /dev/null <<EOF
datacenter = "$DC"
data_dir = "/opt/consul"
node_name = "$INSTANCE_NAME-${node_name}"
node_meta = {
  hostname = "$(hostname)"
  gcp_instance = "$INSTANCE_NAME"
  gcp_zone = "$(curl -H "Metadata-Flavor: Google" "http://metadata.google.internal/computeMetadata/v1/instance/zone" | awk -F / '{print $NF}')"
}
encrypt = "$(cat $CONSUL_DIR/keygen.out)"
retry_join = ["provider=gce project_name=${gcp_project} tag_value=${tag} zone_pattern=\"${zone}-[a-z]\""]
license_path = "$CONSUL_DIR/license.hclic"
log_level = "INFO"

client_addr = "0.0.0.0"
bind_addr = "$PRIVATE_IP"
recursors = ["8.8.8.8","1.1.1.1"]

connect {
  enabled = true
}

tls {
   defaults {
      ca_file = "$CONSUL_DIR/tls/consul-agent-ca.pem"
      verify_incoming = false
      verify_outgoing = true
   }
   internal_rpc {
      verify_server_hostname = false
   }
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

partition = "${partition}"

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
  enabled = false
}
EOF

sudo tee $NOMAD_DIR/client.hcl > /dev/null <<EOF
client {
  enabled = true
  server_join {
    retry_join = ["provider=gce project_name=${gcp_project} tag_value=${tag} zone_pattern=\"${zone}-[a-z]\""]
    retry_max = 3
    retry_interval = "15s"
  }
}
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

# Configure DNS resolution for Consul
sudo mkdir -p /etc/systemd/resolved.conf.d
sudo tee /etc/systemd/resolved.conf.d/consul.conf <<EOF
[Resolve]
DNS=127.0.0.1
DNSSEC=false
Domains=~consul
EOF

sudo iptables --table nat --append OUTPUT --destination localhost --protocol udp --match udp --dport 53 --jump REDIRECT --to-ports 8600
sudo iptables --table nat --append OUTPUT --destination localhost --protocol tcp --match tcp --dport 53 --jump REDIRECT --to-ports 8600
sudo systemctl restart systemd-resolved

echo "==> HashiStack client configuration complete: ${node_name}"