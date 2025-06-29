# HashiStack Terramino Deployment

This repository contains Terraform configuration to deploy a complete HashiCorp stack on Google Cloud Platform (GCP) using **HCP Packer** pre-built images. The deployment includes the Terramino game application along with monitoring tools.

## Architecture

- **3 Nomad/Consul Servers**: Combined server nodes running both Consul and Nomad in server mode
- **2 Nomad Clients**: Worker nodes where applications are deployed
- **1 GCP Load Balancer**: Routes traffic to applications
- **Applications**: Terramino (Tetris game), Grafana, Prometheus
- **Service Mesh**: Consul Connect for secure service communication
- **API Gateway**: Traefik for internal routing
- **Enterprise Features**: ACLs, telemetry, and enterprise licensing
- **HCP Packer**: Pre-built immutable images with Consul 1.20.0+ent and Nomad 1.10.0+ent

## Prerequisites

1. **GCP Account** with billing enabled and existing service account
2. **Terraform Cloud** account with workspace configured
3. **HCP Account** with Packer access for image management
4. **HashiCorp Enterprise Licenses** for Consul and Nomad
5. **Existing GCP Service Account** with appropriate permissions
6. **DNS Zone** (optional, for custom domains)

## Setup Instructions

### 1. Configure Terraform Cloud Variables

#### **Variable Set: "HashiStack Common"**
| Variable | Type | Value | Sensitive | Description |
|----------|------|-------|-----------|-------------|
| `consul_license` | Terraform | `your-consul-enterprise-license` | ✅ Yes | Consul Enterprise License |
| `nomad_license` | Terraform | `your-nomad-enterprise-license` | ✅ Yes | Nomad Enterprise License |
| `consul_version` | Terraform | `1.20.0+ent` | ❌ No | Consul version in Packer images |
| `nomad_version` | Terraform | `1.10.0+ent` | ❌ No | Nomad version in Packer images |
| `consul_datacenter` | Terraform | `dc1` | ❌ No | Consul datacenter name |
| `nomad_datacenter` | Terraform | `dc1` | ❌ No | Nomad datacenter name |
| `enable_acls` | Terraform | `true` | ❌ No | Enable ACLs for Consul and Nomad |
| `enable_tls` | Terraform | `true` | ❌ No | Enable TLS encryption |
| `consul_log_level` | Terraform | `INFO` | ❌ No | Consul log level |
| `nomad_log_level` | Terraform | `INFO` | ❌ No | Nomad log level |

#### **Variable Set: "GCP Common"**
| Variable | Type | Value | Sensitive | Description |
|----------|------|-------|-----------|-------------|
| `GOOGLE_CREDENTIALS` | Environment | `{your-service-account-json}` | ✅ Yes | GCP Service Account JSON |
| `region` | Terraform | `us-central1` | ❌ No | Default GCP region |
| `zone` | Terraform | `us-central1-a` | ❌ No | Default GCP zone |
| `machine_type_server` | Terraform | `e2-standard-2` | ❌ No | Server machine type |
| `machine_type_client` | Terraform | `e2-standard-4` | ❌ No | Client machine type |
| `subnet_cidr` | Terraform | `10.0.0.0/16` | ❌ No | VPC subnet CIDR |

#### **Workspace Variables: "hashistack-terramino-nomad-consul"**
| Variable | Type | Value | Sensitive | Description |
|----------|------|-------|-----------|-------------|
| `project_id` | Terraform | `your-gcp-project-id` | ❌ No | Your GCP Project ID |
| `ssh_public_key` | Terraform | `ssh-rsa AAAAB3NzaC1yc2...` | ✅ Yes | Your SSH public key |
| `gcp_sa` | Terraform | `your-existing-sa@appspot.gserviceaccount.com` | ❌ No | Existing GCP Service Account |
| `dns_zone` | Terraform | `doormat-accountid` | ❌ No | GCP DNS managed zone name |
| `cluster_name` | Terraform | `hashistack-terramino` | ❌ No | Cluster identifier |
| `domain_name` | Terraform | `hashistack.local` | ❌ No | Base domain name |
| `packer_image_channel` | Terraform | `latest` | ❌ No | HCP Packer image channel |

### 2. Build HCP Packer Images

Before deploying infrastructure, you need to build the HashiStack images using HCP Packer.

#### **Prerequisites for Packer Build:**
1. **HCP Account** with Packer access
2. **HCP CLI** authenticated (`hcp auth login`)
3. **Packer** installed locally
4. **GCP credentials** configured

#### **Build Images:**
```bash
# Navigate to packer directory
cd packer/

# Build server image
packer build -var="project_id=your-gcp-project-id" hashistack-server.pkr.hcl

# Build client image
packer build -var="project_id=your-gcp-project-id" hashistack-client.pkr.hcl
```

#### **Verify Images in HCP:**
1. Go to [HCP Packer](https://portal.cloud.hashicorp.com/packer)
2. Check for `hashistack-server` and `hashistack-client` buckets
3. Verify latest iterations are available in the `latest` channel

### 3. Deploy Infrastructure

#### **Terraform Cloud UI** (Recommended)
1. Go to your workspace in Terraform Cloud
2. Click "Queue Plan"
3. Review the plan (should show 15+ resources to create)
4. Click "Confirm & Apply"
5. Wait ~15-20 minutes for deployment

### 4. Verify Deployment

After deployment completes, get the outputs:

```bash
# View outputs
terraform output

# Get sensitive tokens
terraform output -json | jq '.consul_master_token.value'
terraform output -json | jq '.nomad_server_token.value'
```

### 5. Access the Infrastructure

#### **SSH to Server-1:**
```bash
# Get server IP from outputs
export SERVER_IP=$(terraform output -json | jq -r '.consul_servers.value."server-1".public_ip')
ssh ubuntu@$SERVER_IP
```

#### **Check Services:**
```bash
# On the server, check status
sudo systemctl status consul
sudo systemctl status nomad

# Check cluster status
consul members
nomad server members
nomad node status
```

### 6. Deploy Applications

#### **Create Job Files Locally:**

Create `traefik.nomad.hcl`:
```hcl
job "traefik" {
  datacenters = ["dc1"]
  type = "service"

  group "traefik" {
    count = 2

    network {
      port "http" {
        static = 80
      }
      port "api" {
        static = 8080
      }
    }

    service {
      name = "traefik"
      port = "http"
      
      check {
        name     = "alive"
        type     = "tcp"
        port     = "http"
        interval = "10s"
        timeout  = "2s"
      }
    }

    task "traefik" {
      driver = "docker"

      config {
        image        = "traefik:v3.0"
        network_mode = "host"
        ports        = ["http", "api"]
        args = [
          "--api.dashboard=true",
          "--api.insecure=true",
          "--entrypoints.web.address=:80",
          "--entrypoints.traefik.address=:8080",
          "--providers.consul.endpoints=127.0.0.1:8500",
          "--providers.consulcatalog.prefix=traefik",
          "--providers.consulcatalog.exposedbydefault=false",
          "--providers.consulcatalog.endpoints=127.0.0.1:8500"
        ]
      }

      resources {
        cpu    = 200
        memory = 256
      }
    }
  }
}
```

Create `prometheus.nomad.hcl`:
```hcl
job "prometheus" {
  datacenters = ["dc1"]
  type = "service"

  group "prometheus" {
    count = 1

    volume "prometheus_data" {
      type      = "host"
      read_only = false
      source    = "prometheus_data"
    }

    network {
      port "prometheus_ui" {
        to = 9090
      }
    }

    service {
      name = "prometheus"
      port = "prometheus_ui"
      
      check {
        type     = "http"
        path     = "/-/healthy"
        interval = "10s"
        timeout  = "3s"
      }
    }

    task "prometheus" {
      driver = "docker"

      config {
        image = "prom/prometheus:latest"
        ports = ["prometheus_ui"]
        args = [
          "--config.file=/etc/prometheus/prometheus.yml",
          "--storage.tsdb.path=/prometheus",
          "--web.console.libraries=/etc/prometheus/console_libraries",
          "--web.console.templates=/etc/prometheus/consoles",
          "--web.enable-lifecycle"
        ]
      }

      volume_mount {
        volume      = "prometheus_data"
        destination = "/prometheus"
        read_only   = false
      }

      resources {
        cpu    = 500
        memory = 512
      }
    }
  }
}
```

Create `grafana.nomad.hcl`:
```hcl
job "grafana" {
  datacenters = ["dc1"]
  type = "service"

  group "grafana" {
    count = 1

    volume "grafana_data" {
      type      = "host"
      read_only = false
      source    = "grafana_data"
    }

    network {
      port "grafana_ui" {
        to = 3000
      }
    }

    service {
      name = "grafana"
      port = "grafana_ui"
      
      check {
        type     = "http"
        path     = "/api/health"
        interval = "10s"
        timeout  = "3s"
      }
    }

    task "grafana" {
      driver = "docker"

      config {
        image = "grafana/grafana:latest"
        ports = ["grafana_ui"]
      }

      volume_mount {
        volume      = "grafana_data"
        destination = "/var/lib/grafana"
        read_only   = false
      }

      env {
        GF_SECURITY_ADMIN_PASSWORD = "admin"
        GF_INSTALL_PLUGINS = "grafana-clock-panel"
      }

      resources {
        cpu    = 200
        memory = 512
      }
    }
  }
}
```

Create `terramino.nomad.hcl`:
```hcl
job "terramino" {
  datacenters = ["dc1"]
  type = "service"

  group "terramino" {
    count = 2

    network {
      port "http" {
        to = 80
      }
    }

    service {
      name = "terramino"
      port = "http"
      
      check {
        type     = "http"
        path     = "/"
        interval = "10s"
        timeout  = "2s"
      }
    }

    task "web" {
      driver = "docker"

      config {
        image = "nginx:alpine"
        ports = ["http"]
        volumes = [
          "local:/usr/share/nginx/html"
        ]
      }

      artifact {
        source = "https://github.com/hashicorp-education/learn-terramino/archive/refs/heads/main.zip"
        destination = "local/"
      }

      resources {
        cpu    = 200
        memory = 256
      }
    }
  }
}
```

#### **Deploy Jobs:**
```bash
# SSH to a server
ssh ubuntu@<server-ip>

# Set environment variables
export NOMAD_ADDR=http://localhost:4646
export CONSUL_HTTP_ADDR=http://localhost:8500

# Get ACL tokens (if ACLs enabled)
export NOMAD_TOKEN="<nomad-server-token-from-outputs>"
export CONSUL_HTTP_TOKEN="<consul-master-token-from-outputs>"

# Deploy jobs
nomad job run traefik.nomad.hcl
nomad job run prometheus.nomad.hcl
nomad job run grafana.nomad.hcl
nomad job run terramino.nomad.hcl
```

### 7. Access Applications

#### **Direct Access via Client IPs:**
```bash
# Get client IPs from Terraform outputs
terraform output nomad_clients

# Access applications directly
curl http://<client-ip>:9090  # Prometheus
curl http://<client-ip>:3000  # Grafana
```

#### **Via Load Balancer (if DNS configured):**
- **Terramino**: http://terramino-hashistack-terramino.your-domain.com
- **Grafana**: http://grafana-hashistack-terramino.your-domain.com (admin/admin)
- **Prometheus**: http://prometheus-hashistack-terramino.your-domain.com

#### **Direct HashiStack UIs:**
- **Consul UI**: http://<server-ip>:8500
- **Nomad UI**: http://<server-ip>:4646
- **Traefik Dashboard**: http://<client-ip>:8080

### 8. DNS Configuration

#### **Option 1: Use your DNS zone (Automatic)**
If `dns_zone` is configured, DNS records are created automatically.

#### **Option 2: Manual DNS/Hosts Configuration**
Add to your local `/etc/hosts` file:
```
<load-balancer-ip> terramino-hashistack-terramino.hashistack.local
<load-balancer-ip> grafana-hashistack-terramino.hashistack.local
<load-balancer-ip> prometheus-hashistack-terramino.hashistack.local
```

## Accessing Grafana and Prometheus

### **Direct Access (Easiest)**
1. Get client IPs: `terraform output nomad_clients`
2. **Grafana**: http://CLIENT_IP:3000 (admin/admin)
3. **Prometheus**: http://CLIENT_IP:9090

### **Via Load Balancer**
1. Get load balancer IP: `terraform output load_balancer_ip`
2. Add Host headers or configure DNS
3. **Grafana**: http://LB_IP with Host header `grafana-hashistack-terramino.hashistack.local`
4. **Prometheus**: http://LB_IP with Host header `prometheus-hashistack-terramino.hashistack.local`

### **Browser Access Commands**
```bash
# Get the IPs
LB_IP=$(terraform output -raw load_balancer_ip)
CLIENT_IP=$(terraform output -json | jq -r '.nomad_clients.value."client-1".public_ip')

# Direct access URLs
echo "Grafana: http://$CLIENT_IP:3000 (admin/admin)"
echo "Prometheus: http://$CLIENT_IP:9090"
echo "Consul: http://$(terraform output -json | jq -r '.consul_servers.value."server-1".public_ip'):8500"
echo "Nomad: http://$(terraform output -json | jq -r '.consul_servers.value."server-1".public_ip'):4646"
```

## Architecture Details

### Security Features
- **ACLs Enabled**: Both Consul and Nomad have ACL systems enabled
- **Enterprise Licensing**: Uses HashiCorp Enterprise features
- **Firewall Rules**: Restrictive firewall rules allowing only necessary ports
- **Service Account**: Uses existing GCP service account with appropriate permissions

### High Availability
- **3-Server Cluster**: Consul and Nomad servers form a 3-node cluster
- **Load Balancing**: GCP Load Balancer distributes traffic across client nodes
- **Health Checks**: Comprehensive health checking for all services
- **Auto-Recovery**: Services automatically restart on failure

### Monitoring & Observability
- **Prometheus**: Metrics collection from all HashiStack components
- **Grafana**: Visualization and dashboarding with admin/admin credentials
- **Telemetry**: Comprehensive telemetry configuration for all services

## Troubleshooting

### Common Issues

1. **Services not starting**:
   ```bash
   # Check service status
   sudo systemctl status consul
   sudo systemctl status nomad
   
   # Check logs
   sudo journalctl -u consul -f
   sudo journalctl -u nomad -f
   ```

2. **Jobs not deploying**:
   ```bash
   # Check node status
   nomad node status
   
   # Check job status
   nomad job status
   nomad alloc status <alloc-id>
   ```

3. **Cannot access applications**:
   ```bash
   # Check if jobs are running
   nomad job status
   
   # Check service registration
   consul catalog services
   
   # Check port allocation
   nomad alloc status <alloc-id>
   ```

### Useful Commands

```bash
# Check cluster status
consul members
nomad server members
nomad node status

# View job status
nomad job status
nomad alloc status <alloc-id>

# Access logs
nomad alloc logs <alloc-id>
nomad alloc logs -f <alloc-id>

# Service discovery
consul catalog services
consul catalog nodes
```

## Cleanup

To destroy all resources:

```bash
terraform destroy
```

**Warning**: This will permanently delete all infrastructure and data.

## Key Benefits of HCP Packer Approach

- **Faster Deployments**: Pre-built images reduce deployment time from ~20 minutes to ~5 minutes
- **Immutable Infrastructure**: Consistent, tested images with baked-in configurations
- **Version Control**: HCP Packer tracks image iterations and channels for rollbacks
- **Simplified Terraform**: Removed 270+ line startup scripts, replaced with 20-line configurations
- **Enterprise Ready**: Uses Consul 1.20.0+ent and Nomad 1.10.0+ent with proper licensing

## Key Differences from Standard Deployment

- **Uses existing GCP service account** instead of creating new one
- **Leverages existing DNS zone** for domain management
- **Pre-built images** via HCP Packer instead of runtime installation
- **Simplified permissions** model using existing service accounts
- **Enterprise features** enabled with proper licensing
- **HCP Packer registry** for image metadata and version tracking
