#!/bin/bash

CONSUL_DIR="/etc/consul.d"

NODE_HOSTNAME=$(curl -H 'Metadata-Flavor:Google' http://metadata.google.internal/computeMetadata/v1/instance/hostname)
PUBLIC_IP=$(curl -H 'Metadata-Flavor:Google' http://metadata.google.internal/computeMetadata/v1/instance/network-interfaces/0/access-configs/0/external-ip)
PRIVATE_IP=$(curl -H 'Metadata-Flavor:Google' http://metadata.google.internal/computeMetadata/v1/instance/network-interfaces/0/ip)
DC="${dc_name}"
CONSUL_LICENSE="${consul_license}"
NOMAD_LICENSE="${nomad_license}"
NOMAD_DIR="/etc/nomad.d"
NOMAD_URL="https://releases.hashicorp.com/nomad"
CNI_PLUGIN_VERSION="v1.5.1"


# ---- Check directories ----
if [ -d "$CONSUL_DIR" ];then
    echo "Consul configurations will be created in $CONSUL_DIR" >> /tmp/consul-log.out
else
    echo "Consul configurations directoy does not exist. Exiting..." >> /tmp/consul-log.out
    exit 1
fi

if [ -d "/opt/consul" ]; then
    echo "Consul data directory will be created at existing /opt/consul" >> /tmp/consul-log.out
else
    echo "/opt/consul does not exist. Check that VM image is the right one. Creating directory anyway..."
    sudo mkdir -p /opt/consul
    sudo chown -R consul:consul /opt/consul
fi

# Creating a directory for audit
sudo mkdir -p /tmp/consul/audit


# ---- Enterprise Licenses ----
echo $CONSUL_LICENSE | sudo tee $CONSUL_DIR/license.hclic > /dev/null
echo $NOMAD_LICENSE | sudo tee $NOMAD_DIR/license.hclic > /dev/null

# ----------------------------------
echo "==> Generating Consul configs"

sudo tee $CONSUL_DIR/consul.hcl > /dev/null <<EOF
datacenter = "$DC"
data_dir = "/opt/consul"
node_name = "${node_name}"
node_meta = {
  hostname = "$(hostname)"
  gcp_instance = "$(curl "http://metadata.google.internal/computeMetadata/v1/instance/name" -H "Metadata-Flavor: Google")"
  gcp_zone = "$(curl -H "Metadata-Flavor: Google" "http://metadata.google.internal/computeMetadata/v1/instance/zone" | awk -F / '{print $NF}')"
  type = "client"
  nomad_client = "true"
}
encrypt = "${consul_encrypt_key}"
retry_join = ["provider=gce project_name=${gcp_project} tag_value=${tag} zone_pattern=\"${zone}-[a-z]\""]
license_path = "$CONSUL_DIR/license.hclic"
log_level = "DEBUG"


tls {
   defaults {
      ca_file = "$CONSUL_DIR/tls/consul-agent-ca.pem"
      verify_incoming = false
      verify_outgoing = true
      verify_server_hostname = false
   }
   internal_rpc {
      verify_server_hostname = false
   }
}

auto_encrypt {
  tls = true
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

reporting {
  license {
    enabled = false
  }
}


partition ="${partition}"

client_addr = "0.0.0.0"
bind_addr = "$PRIVATE_IP"
recursors = ["8.8.8.8","1.1.1.1"]


ports {
  https = 8501
  grpc = 8502
  grpc_tls = 8503
}

connect {
  enabled = true
}

telemetry {
  prometheus_retention_time = "30s"
  disable_hostname = true
}

service {
  name = "nomad-client"
  tags = ["nomad-client", "hashistack"]
  port = 4646
  check {
    http = "http://localhost:4646/v1/agent/health"
    interval = "10s"
  }
}

EOF


echo "==> Creating the Consul service"
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

# ---- Preparing certificates ----
echo "==> Adding CA certificate for clients"
sudo mkdir -p "$CONSUL_DIR"/tls
echo "${consul_ca_cert}" | sudo tee "$CONSUL_DIR"/tls/consul-agent-ca.pem > /dev/null

# Let's set some permissions to read certificates from Consul
echo "==> Changing permissions for Consul"
sudo chown -R consul:consul "$CONSUL_DIR"/tls
sudo chown -R consul:consul /tmp/consul/audit


# ---------------

# ----- NOMAD CONFIG --------


# ---- Check directories ----
if [ -d "$NOMAD_DIR" ];then
    echo "Nomad configurations will be created in $NOMAD_DIR" >> /tmp/nomad-log.out
else
    echo "Nomad configurations directoy does not exist. Exiting..." >> /tmp/nomad-log.out
    exit 1
fi

if [ -d "/opt/nomad" ]; then
    echo "Consul data directory will be created at existing /opt/nomad" >> /tmp/nomad-log.out
else
    echo "/opt/nomad does not exist. Check that VM image is the right one. Creating directory anyway..."
    sudo mkdir -p /opt/nomad
    sudo chown -R nomad:nomad /opt/nomad
fi

# Installing CNI plugins
curl -L -o cni-plugins.tgz "https://github.com/containernetworking/plugins/releases/download/$CNI_PLUGIN_VERSION/cni-plugins-linux-$( [ $(uname -m) = aarch64 ] && echo arm64 || echo amd64)"-$CNI_PLUGIN_VERSION.tgz
sudo mkdir -p /opt/cni/bin
sudo tar -C /opt/cni/bin -xzf cni-plugins.tgz

# Installing Consul CNI
export ARCH_CNI="$( [ $(uname -m) = aarch64 ] && echo arm64 || echo amd64)"
curl -L -o consul-cni.zip "https://releases.hashicorp.com/consul-cni/1.5.1/consul-cni_1.5.1_linux_$ARCH_CNI".zip
sudo unzip consul-cni.zip -d /opt/cni/bin -x LICENSE.txt


# ----------------------------------
echo "==> Generating Nomad configs"

sudo tee $NOMAD_DIR/nomad.hcl > /dev/null <<EOF
datacenter = "$DC"
data_dir = "/opt/nomad"
acl  {
  enabled = true
}
telemetry {
  collection_interval = "1s"
  disable_hostname = true
  prometheus_metrics = true
  publish_allocation_metrics = true
  publish_node_metrics = true
}

consul {
  address = "127.0.0.1:8500"
  grpc_address = "127.0.0.1:8502"
  enabled = true
  token = "${bootstrap_token}"
  
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


sudo tee $NOMAD_DIR/client.hcl > /dev/null <<EOF
client {
  enabled = true
  servers = ["provider=gce project_name=${gcp_project} tag_value=${tag}"]
}
EOF

echo "==> Creating the Nomad service"
sudo tee /usr/lib/systemd/system/nomad.service > /dev/null <<EOF
[Unit]
Description=Nomad
Documentation=https://www.nomadproject.io/docs/
Wants=network-online.target
After=network-online.target

# When using Nomad with Consul it is not necessary to start Consul first. These
# lines start Consul before Nomad as an optimization to avoid Nomad logging
# that Consul is unavailable at startup.
#Wants=consul.service
#After=consul.service

[Service]

ExecReload=/bin/kill -HUP \$MAINPID
ExecStart=/usr/bin/nomad agent -config $NOMAD_DIR
KillMode=process
KillSignal=SIGINT
LimitNOFILE=65536
LimitNPROC=infinity
Restart=on-failure
RestartSec=2

## Configure unit start rate limiting. Units which are started more than
## *burst* times within an *interval* time span are not permitted to start any
## more. Use `StartLimitIntervalSec` or `StartLimitInterval` (depending on
## systemd version) to configure the checking interval and `StartLimitBurst`
## to configure how many starts per interval are allowed. The values in the
## commented lines are defaults.

# StartLimitBurst = 5

## StartLimitIntervalSec is used for systemd versions >= 230
# StartLimitIntervalSec = 10s

## StartLimitInterval is used for systemd versions < 230
# StartLimitInterval = 10s

TasksMax=infinity
OOMScoreAdjust=-1000

[Install]
WantedBy=multi-user.target
EOF


# Let's set some permissions to read certificates from Nomad
echo "==> Changing permissions for Nomad"
sudo chown -R nomad:nomad "$NOMAD_DIR"

# INIT SERVICES

echo "==> Starting Consul..."
sudo systemctl enable consul
sudo systemctl start consul

# Wait for consul to be ready
echo "==> Waiting for Consul to be ready..."
export CONSUL_HTTP_ADDR=http://127.0.0.1:8500
export CONSUL_HTTP_TOKEN="${bootstrap_token}"
for i in {1..30}; do
  if consul catalog services >/dev/null 2>&1; then
    echo "Consul is ready"
    break
  fi
  echo "Waiting for Consul... ($i/30)"
  sleep 10
done

echo "==> Starting Nomad..."
sudo systemctl enable nomad
sudo systemctl start nomad