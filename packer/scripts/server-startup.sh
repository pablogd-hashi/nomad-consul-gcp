#!/bin/bash
set -e

# Template variables (these names must match what's passed from Terraform)
CONSUL_VERSION="${consul_version}"
NOMAD_VERSION="${nomad_version}"
CONSUL_DATACENTER="${consul_datacenter}"
NOMAD_DATACENTER="${nomad_datacenter}"
CONSUL_ENCRYPT_KEY="${consul_encrypt_key}"
CONSUL_MASTER_TOKEN="${consul_master_token}"
NOMAD_CONSUL_TOKEN="${nomad_consul_token}"
NOMAD_SERVER_TOKEN="${nomad_server_token}"
NOMAD_CLIENT_TOKEN="${nomad_client_token}"
CONSUL_LICENSE="${consul_license}"
NOMAD_LICENSE="${nomad_license}"
SERVER_INDEX="${server_index}"
SERVER_COUNT="${server_count}"
CA_CERT="${ca_cert}"
CA_KEY="${ca_key}"
SUBNET_CIDR="${subnet_cidr}"
ENABLE_ACLS="${enable_acls}"
ENABLE_TLS="${enable_tls}"
CONSUL_LOG_LEVEL="${consul_log_level}"
NOMAD_LOG_LEVEL="${nomad_log_level}"
PROJECT_ID="${project_id}"

# Get instance metadata
INSTANCE_NAME=$(curl -s "http://metadata.google.internal/computeMetadata/v1/instance/name" -H "Metadata-Flavor: Google")
PRIVATE_IP=$(curl -s "http://metadata.google.internal/computeMetadata/v1/instance/network-interfaces/0/ip" -H "Metadata-Flavor: Google")
PUBLIC_IP=$(curl -s "http://metadata.google.internal/computeMetadata/v1/instance/network-interfaces/0/access-configs/0/external-ip" -H "Metadata-Flavor: Google")
ZONE=$(curl -s "http://metadata.google.internal/computeMetadata/v1/instance/zone" -H "Metadata-Flavor: Google" | cut -d/ -f4)

# Update system
apt-get update
apt-get install -y unzip curl jq docker.io docker-compose

# Start and enable Docker
systemctl start docker
systemctl enable docker
usermod -aG docker ubuntu

# Install Google Cloud SDK
curl https://sdk.cloud.google.com | bash
source /home/ubuntu/.bashrc

# Create directories
mkdir -p /opt/consul/{bin,data,config,logs}
mkdir -p /opt/nomad/{bin,data,config,logs}
mkdir -p /etc/ssl/hashistack

# Download and install Consul
cd /tmp
wget "https://releases.hashicorp.com/consul/$CONSUL_VERSION/consul_${CONSUL_VERSION}_linux_amd64.zip"
unzip "consul_${CONSUL_VERSION}_linux_amd64.zip"
mv consul /opt/consul/bin/
chmod +x /opt/consul/bin/consul
ln -s /opt/consul/bin/consul /usr/local/bin/consul

# Download and install Nomad
wget "https://releases.hashicorp.com/nomad/$NOMAD_VERSION/nomad_${NOMAD_VERSION}_linux_amd64.zip"
unzip "nomad_${NOMAD_VERSION}_linux_amd64.zip"
mv nomad /opt/nomad/bin/
chmod +x /opt/nomad/bin/nomad
ln -s /opt/nomad/bin/nomad /usr/local/bin/nomad

# Create CA certificate
echo "$CA_CERT" | base64 -d > /etc/ssl/hashistack/ca.pem
echo "$CA_KEY" | base64 -d > /etc/ssl/hashistack/ca-key.pem
chmod 600 /etc/ssl/hashistack/ca-key.pem

# Generate server certificates
if [ "$ENABLE_TLS" = "true" ]; then
    # Generate Consul server certificate
    consul tls cert create -server -dc $CONSUL_DATACENTER -ca /etc/ssl/hashistack/ca.pem -key /etc/ssl/hashistack/ca-key.pem
    mv $CONSUL_DATACENTER-server-consul-0-key.pem /etc/ssl/hashistack/consul-server-key.pem
    chmod 600 /etc/ssl/hashistack/consul-server-key.pem

    # Generate Nomad server certificate
    nomad tls cert create -server -region global -ca /etc/ssl/hashistack/ca.pem -key /etc/ssl/hashistack/ca-key.pem
    mv global-server-nomad.pem /etc/ssl/hashistack/nomad-server.pem
    mv global-server-nomad-key.pem /etc/ssl/hashistack/nomad-server-key.pem
    chmod 600 /etc/ssl/hashistack/nomad-server-key.pem
fi

# Create users
useradd --system --home /etc/consul.d --shell /bin/false consul
useradd --system --home /etc/nomad.d --shell /bin/false nomad

# Set ownership
chown -R consul:consul /opt/consul
chown -R nomad:nomad /opt/nomad
chown consul:consul /etc/ssl/hashistack/consul*
chown nomad:nomad /etc/ssl/hashistack/nomad*

# Create Consul configuration
cat > /opt/consul/config/consul.hcl << EOF
datacenter = "$CONSUL_DATACENTER"
data_dir = "/opt/consul/data"
log_level = "$CONSUL_LOG_LEVEL"
node_name = "$INSTANCE_NAME"
server = true
bootstrap_expect = $SERVER_COUNT
retry_join = ["provider=gce project_name=$PROJECT_ID tag_value=consul-server"]

bind_addr = "$PRIVATE_IP"
client_addr = "0.0.0.0"

ui_config {
  enabled = true
}

connect {
  enabled = true
}

enterprise {
  license = "$CONSUL_LICENSE"
}

encrypt = "$CONSUL_ENCRYPT_KEY"

$(if [ "$ENABLE_ACLS" = "true" ]; then
cat << ACL_EOF
acl = {
  enabled = true
  default_policy = "deny"
  enable_token_persistence = true
  tokens {
    initial_management = "$CONSUL_MASTER_TOKEN"
  }
}
ACL_EOF
fi)

$(if [ "$ENABLE_TLS" = "true" ]; then
cat << TLS_EOF
tls {
  defaults {
    ca_file = "/etc/ssl/hashistack/ca.pem"
    cert_file = "/etc/ssl/hashistack/consul-server.pem"
    key_file = "/etc/ssl/hashistack/consul-server-key.pem"
    verify_incoming = true
    verify_outgoing = true
  }
  internal_rpc {
    verify_server_hostname = true
  }
}
TLS_EOF
fi)

telemetry {
  prometheus_retention_time = "24h"
  disable_hostname = true
}

logging {
  log_file_path = "/opt/consul/logs/"
  log_rotate_duration = "24h"
  log_rotate_max_files = 7
}

ports {
  grpc = 8502
}
EOF

# Create Nomad configuration
cat > /opt/nomad/config/nomad.hcl << EOF
datacenter = "$NOMAD_DATACENTER"
data_dir = "/opt/nomad/data"
log_level = "$NOMAD_LOG_LEVEL"
name = "$INSTANCE_NAME"

server {
  enabled = true
  bootstrap_expect = $SERVER_COUNT
  
  server_join {
    retry_join = ["provider=gce project_name=$PROJECT_ID tag_value=nomad-server"]
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
  
$(if [ "$ENABLE_ACLS" = "true" ]; then
cat << CONSUL_ACL_EOF
  token = "$NOMAD_CONSUL_TOKEN"
CONSUL_ACL_EOF
fi)

$(if [ "$ENABLE_TLS" = "true" ]; then
cat << CONSUL_TLS_EOF
  ca_file = "/etc/ssl/hashistack/ca.pem"
  cert_file = "/etc/ssl/hashistack/consul-server.pem"
  key_file = "/etc/ssl/hashistack/consul-server-key.pem"
  ssl = true
CONSUL_TLS_EOF
fi)
}

$(if [ "$ENABLE_ACLS" = "true" ]; then
cat << NOMAD_ACL_EOF
acl {
  enabled = true
  token_ttl = "30s"
  policy_ttl = "60s"
  role_ttl = "60s"
}
NOMAD_ACL_EOF
fi)

$(if [ "$ENABLE_TLS" = "true" ]; then
cat << NOMAD_TLS_EOF
tls {
  http = true
  rpc  = true

  ca_file   = "/etc/ssl/hashistack/ca.pem"
  cert_file = "/etc/ssl/hashistack/nomad-server.pem"
  key_file  = "/etc/ssl/hashistack/nomad-server-key.pem"

  verify_server_hostname = true
  verify_https_client    = true
}
NOMAD_TLS_EOF
fi)

telemetry {
  collection_interval = "1s"
  disable_hostname = true
  prometheus_metrics = true
  publish_allocation_metrics = true
  publish_node_metrics = true
}

logging {
  log_file_path = "/opt/nomad/logs/"
  log_rotate_duration = "24h"
  log_rotate_max_files = 7
}

ui {
  enabled = true
  consul {
    ui_url = "http://localhost:8500/ui"
  }
}

workload_identity {
  audience = ["gcp"]
  claim_mappings = {
    "project_id" = "project_id"
    "instance_id" = "instance_id"
  }
}
EOF

# Create systemd service for Consul
cat > /etc/systemd/system/consul.service << EOF
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
ExecReload=/bin/kill -HUP \$MAINPID
KillMode=process
Restart=on-failure
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF

# Create systemd service for Nomad
cat > /etc/systemd/system/nomad.service << EOF
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
ExecReload=/bin/kill -HUP \$MAINPID
KillMode=process
Restart=on-failure
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF

# Start services
systemctl daemon-reload
systemctl enable consul
systemctl start consul

# Wait for Consul to be ready
sleep 30

systemctl enable nomad
systemctl start nomad

# Wait for Nomad to be ready
sleep 30

# Configure ACLs if enabled
if [ "$ENABLE_ACLS" = "true" ] && [ "$SERVER_INDEX" = "1" ]; then
    # Wait for Consul cluster to be ready
    sleep 60
    
    # Bootstrap Consul ACLs and create tokens
    export CONSUL_HTTP_TOKEN="$CONSUL_MASTER_TOKEN"
    
    # Create Nomad policy for Consul
    consul acl policy create \
        -name "nomad-server" \
        -description "Policy for Nomad servers" \
        -rules '@/opt/consul/nomad-server-policy.hcl'
    
    # Create Nomad token
    consul acl token create \
        -description "Token for Nomad servers" \
        -policy-name "nomad-server" \
        -secret "$NOMAD_CONSUL_TOKEN"
    
    # Bootstrap Nomad ACLs
    export NOMAD_TOKEN="$NOMAD_SERVER_TOKEN"
    nomad acl bootstrap -initial-management-token="$NOMAD_SERVER_TOKEN"
fi

# Create Consul policy for Nomad
cat > /opt/consul/nomad-server-policy.hcl << EOF
node_prefix "" {
  policy = "write"
}

service_prefix "" {
  policy = "write"
}

agent_prefix "" {
  policy = "write"
}

key_prefix "" {
  policy = "write"
}

acl = "write"
EOF

echo "Server setup complete".pem /etc/ssl/hashistack/consul-server.pem
    mv $CONSUL_DATACENTER-server-consul-0
