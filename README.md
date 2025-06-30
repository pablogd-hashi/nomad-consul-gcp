# HashiStack on Google Cloud Platform

> **Production-ready HashiCorp Consul and Nomad deployment on GCP with enterprise features, service mesh, and monitoring.**

## 🏗️ Architecture

This repository deploys a complete HashiStack environment including:

- **3 Server Nodes**: Combined Consul/Nomad servers (e2-standard-2)
- **2 Client Nodes**: Nomad workers for applications (e2-standard-4)  
- **GCP Load Balancer**: Global HTTP load balancer with DNS
- **Service Mesh**: Consul Connect for secure service communication
- **Enterprise Security**: ACLs enabled, TLS encryption, firewall rules
- **Monitoring**: Prometheus + Grafana + Traefik dashboard

## 🚀 Quick Start

### Prerequisites

1. **GCP Project** with billing enabled
2. **Terraform Cloud** account (or local Terraform ≥ 1.0)
3. **Valid Enterprise Licenses** for Consul and Nomad
4. **Required APIs enabled**:
   ```bash
   gcloud services enable compute.googleapis.com
   gcloud services enable dns.googleapis.com
   gcloud services enable cloudresourcemanager.googleapis.com
   ```

### Option 1: Using HCP Packer (Recommended)

**Benefits**: Pre-built, optimized images with Consul/Nomad already installed

#### Step 1: Build Images with HCP Packer

```bash
# Set up HCP Packer credentials
export HCP_CLIENT_ID="your-hcp-client-id"
export HCP_CLIENT_SECRET="your-hcp-client-secret"

# Configure Packer variables
cd packer/
cp variables/common.pkrvars.hcl.example variables/common.pkrvars.hcl
# Edit common.pkrvars.hcl with your GCP project ID

# Build server and client images
packer build -var-file=variables/common.pkrvars.hcl builds/hashistack-server.pkr.hcl
packer build -var-file=variables/common.pkrvars.hcl builds/hashistack-client.pkr.hcl
```

#### Step 2: Deploy Infrastructure with HCP Packer Images

```bash
# Configure Terraform
cd terraform/
cp terraform.tfvars.example terraform.tfvars

# Edit terraform.tfvars with:
# use_hcp_packer = true
# Your other required variables

# Deploy
terraform init
terraform plan
terraform apply
```

### Option 2: Using Base Ubuntu Images (Faster Setup)

**Benefits**: No need to build custom images, faster initial deployment

#### Deploy with Base Images

```bash
# Configure Terraform
cd terraform/
cp terraform.tfvars.example terraform.tfvars

# Edit terraform.tfvars with:
# use_hcp_packer = false
# Your other required variables

# Deploy - will install Consul/Nomad via startup scripts
terraform init
terraform plan
terraform apply
```

## 📋 Required Configuration

### Terraform Variables (`terraform/terraform.tfvars`)

```hcl
# Required Variables
project_id     = "your-gcp-project-id"
ssh_public_key = "ssh-rsa AAAAB3NzaC1yc2E..."
consul_license = "02MV4UU43BK5..."  # Enterprise license
nomad_license  = "02MV4UU43BK5..."  # Enterprise license

# Image Strategy (choose one)
use_hcp_packer = true   # Use HCP Packer images (recommended)
# OR
use_hcp_packer = false  # Use base Ubuntu with startup scripts

# Optional (with defaults)
region             = "us-central1"
zone               = "us-central1-a"
machine_type_server = "e2-standard-2"
machine_type_client = "e2-standard-4"
cluster_name       = "hashistack"
```

### HCP Packer Variables (`packer/variables/common.pkrvars.hcl`)

```hcl
# Required for HCP Packer workflow
gcp_project = "your-gcp-project-id"
gcp_zone    = "us-central1-a"

# HashiCorp software versions
consul_version = "1.21.2+ent"
nomad_version  = "1.10.2+ent"
```

## 🛠️ Available Scripts

### Infrastructure Management

```bash
# From terraform/ directory
terraform plan                    # Preview changes
terraform apply                   # Deploy infrastructure
terraform destroy                 # Destroy all resources
terraform output                  # Show all outputs
terraform output consul_ui_urls   # Show Consul UI URLs
terraform output nomad_ui_urls    # Show Nomad UI URLs
```

### Token Management

```bash
# Get all authentication tokens and URLs
./scripts/get-tokens.sh

# Set up environment variables for CLI access (recommended)
./scripts/setup-env.sh

# Get Nomad UI authentication help
./scripts/nomad-ui-auth.sh

# Or source setup script to set variables in current shell
source ./scripts/setup-env.sh

# Outputs:
# - Consul Master Token
# - Nomad Server Token  
# - Nomad Client Token
# - Application Token
# - Encryption Keys
# - Quick CLI setup commands
# - Connectivity tests
```

### Image Building (HCP Packer)

```bash
# Build server image
cd packer/
packer build -var-file=variables/common.pkrvars.hcl builds/hashistack-server.pkr.hcl

# Build client image  
packer build -var-file=variables/common.pkrvars.hcl builds/hashistack-client.pkr.hcl

# Validate Packer configurations
packer validate -var-file=variables/common.pkrvars.hcl builds/hashistack-server.pkr.hcl
```

### Application Deployment

```bash
# SSH to first server
SERVER_IP=$(cd terraform && terraform output -json consul_servers | jq -r '.["server-1"].public_ip')
ssh ubuntu@$SERVER_IP

# On the server, deploy applications
export NOMAD_ADDR=http://localhost:4646
export NOMAD_TOKEN="$(cat /opt/consul/nomad-server-token)"

# Deploy core services
nomad job run /opt/nomad/jobs/traefik.nomad.hcl
nomad job run /opt/nomad/jobs/prometheus.nomad.hcl
nomad job run /opt/nomad/jobs/grafana.nomad.hcl

# Deploy applications
nomad job run /opt/nomad/jobs/terramino.nomad.hcl

# Check job status
nomad job status
nomad node status
```

### System Administration

```bash
# SSH to any server
ssh ubuntu@<server-ip>

# Check service status
sudo systemctl status consul
sudo systemctl status nomad
sudo journalctl -u consul -f
sudo journalctl -u nomad -f

# Consul operations
export CONSUL_HTTP_ADDR=http://localhost:8500
export CONSUL_HTTP_TOKEN="$(cat /opt/consul/management-token)"
consul members
consul catalog services

# Nomad operations  
export NOMAD_ADDR=http://localhost:4646
export NOMAD_TOKEN="$(cat /opt/consul/nomad-server-token)"
nomad server members
nomad node status
nomad job status
```

## 🔐 Security & Access

### Authentication

All services use ACL tokens generated automatically:

- **Consul Master Token**: Full administrative access
- **Nomad Server Token**: Nomad server access to Consul
- **Nomad Client Token**: Nomad client access to Consul  
- **Application Token**: Service registration access

### Access Points

After deployment, access services via:

```bash
# Get URLs from Terraform
terraform output consul_ui_urls    # Consul UI
terraform output nomad_ui_urls     # Nomad UI
terraform output application_urls  # Load balancer URLs

# Or use the get-tokens script for everything
./scripts/get-tokens.sh
```

### CLI Setup

```bash
# Quick setup - use the setup script (recommended)
./scripts/setup-env.sh

# Or manually set environment variables
export CONSUL_HTTP_ADDR=http://<server-ip>:8500
export CONSUL_HTTP_TOKEN=<consul-master-token>
export NOMAD_ADDR=http://<server-ip>:4646  
export NOMAD_TOKEN=<nomad-server-token>

# Test connectivity
consul members
nomad node status

# Set up Nomad-Consul integration (run once after deployment)
nomad setup consul -y
```

### UI Authentication

```bash
# For Consul UI
# Navigate to http://<server-ip>:8500
# Use the Consul master token from: terraform output -raw consul_master_token

# For Nomad UI (use the helper script - recommended)
./scripts/nomad-ui-auth.sh

# Manual Nomad UI access:
# 1. Navigate to http://<server-ip>:4646
# 2. Click "ACL Tokens" in top-right corner  
# 3. Paste the token from: terraform output -raw nomad_server_token

# Note: 'nomad ui -authenticate' doesn't work with bootstrap management tokens
# The helper script explains why and provides working alternatives
```

## 🔄 Deployment Workflows

### HCP Packer Workflow (Production)

1. **Build Images** → 2. **Deploy Infrastructure** → 3. **Deploy Applications**

```bash
# 1. Build images (once, or when updating versions)
cd packer/
packer build -var-file=variables/common.pkrvars.hcl builds/hashistack-server.pkr.hcl
packer build -var-file=variables/common.pkrvars.hcl builds/hashistack-client.pkr.hcl

# 2. Deploy infrastructure
cd ../terraform/
terraform apply

# 3. Deploy applications
SERVER_IP=$(terraform output -json consul_servers | jq -r '.["server-1"].public_ip')
ssh ubuntu@$SERVER_IP
# Deploy jobs as shown above
```

### Base Image Workflow (Development)

1. **Deploy Infrastructure** → 2. **Deploy Applications**

```bash
# 1. Deploy infrastructure (installs software via startup scripts)
cd terraform/
terraform apply

# 2. Deploy applications  
SERVER_IP=$(terraform output -json consul_servers | jq -r '.["server-1"].public_ip')
ssh ubuntu@$SERVER_IP
# Deploy jobs as shown above
```

## 📁 Repository Structure

```
├── terraform/              # Infrastructure as Code
│   ├── main.tf             # Core resources (VPC, networking, certificates)
│   ├── servers.tf          # Consul/Nomad server instances
│   ├── clients.tf          # Nomad client instances
│   ├── load_balancer.tf    # GCP HTTP load balancer
│   ├── packer.tf           # HCP Packer data sources
│   ├── variables.tf        # Input variables
│   ├── outputs.tf          # Tokens, URLs, SSH commands
│   └── terraform.tfvars.example
├── packer/                 # Custom image builds
│   ├── builds/             # Packer configurations
│   │   ├── hashistack-server.pkr.hcl
│   │   └── hashistack-client.pkr.hcl
│   ├── scripts/            # Provisioning scripts
│   │   ├── consul_prep.sh
│   │   └── nomad_prep.sh
│   └── variables/          # Packer variables
├── nomad-jobs/             # Application deployments
│   ├── core/              # Infrastructure services
│   │   ├── traefik.nomad.hcl
│   │   ├── prometheus.nomad.hcl
│   │   └── grafana.nomad.hcl
│   └── applications/       # Application workloads
│       └── terramino.nomad.hcl
├── scripts/               # Automation utilities
│   ├── get-tokens.sh      # Get all authentication tokens
│   ├── setup-env.sh       # Set up CLI environment variables
│   ├── nomad-ui-auth.sh   # Nomad UI authentication helper
│   ├── bootstrap-acls.sh  # ACL initialization (internal)
│   └── setup-acl-policies.sh
└── docs/                  # Documentation
```

## 🎯 Features

### ✅ Enterprise Ready
- Consul Enterprise with licensing
- Nomad Enterprise with licensing  
- ACL security enabled by default
- TLS encryption ready
- Audit logging configured

### ✅ Service Discovery
- Automatic service registration
- DNS-based service discovery
- HTTP API service catalog
- Health check integration

### ✅ Service Mesh
- Consul Connect enabled
- Automatic sidecar injection
- mTLS between services
- Intention-based security

### ✅ Monitoring
- Prometheus metrics collection
- Grafana dashboards
- Service health monitoring
- Resource utilization tracking

### ✅ Load Balancing
- GCP HTTP Load Balancer
- Traefik API Gateway
- Automatic service routing
- SSL termination

## 🔧 Customization

### Environment-Specific Deployments

```bash
# Development (smaller instances, basic monitoring)
cd terraform/environments/dev/
terraform init
terraform apply

# Production (HA setup, full monitoring)
cd terraform/environments/prod/
terraform apply
```

### Custom Applications

Add your own Nomad jobs to `nomad-jobs/applications/`:

```hcl
# nomad-jobs/applications/my-app.nomad.hcl
job "my-app" {
  datacenters = ["dc1"]
  type        = "service"
  
  group "app" {
    count = 2
    
    task "web" {
      driver = "docker"
      config {
        image = "my-app:latest"
        ports = ["http"]
      }
      
      service {
        name = "my-app"
        port = "http"
        provider = "consul"
        
        check {
          type     = "http"
          path     = "/health"
          interval = "10s"
          timeout  = "2s"
        }
      }
    }
  }
}
```

## 🐛 Troubleshooting

### Common Issues

**Image Build Failures (HCP Packer)**
```bash
# Check Packer logs
packer build -debug -var-file=variables/common.pkrvars.hcl builds/hashistack-server.pkr.hcl

# Verify HCP credentials
export HCP_CLIENT_ID="your-id"
export HCP_CLIENT_SECRET="your-secret"
```

**Terraform Plan Fails with HCP Packer**
```bash
# Ensure images exist in HCP Packer
# Check bucket names match in packer.tf
# Verify region/zone configuration
```

**Service Startup Issues**
```bash
# SSH to server and check logs
ssh ubuntu@<server-ip>
sudo journalctl -u consul -f
sudo journalctl -u nomad -f

# Check token files exist
ls -la /opt/consul/
```

**Application Deployment Fails**
```bash
# Check Nomad job status
nomad job status <job-name>
nomad alloc status <alloc-id>
nomad alloc logs <alloc-id>

# Verify tokens are set
echo $NOMAD_TOKEN
echo $CONSUL_HTTP_TOKEN
```

**Nomad UI Authentication Issues**
```bash
# 'nomad ui -authenticate' fails with 403 error
# This is expected with bootstrap management tokens

# Solution: Use the helper script
./scripts/nomad-ui-auth.sh

# Or manually paste token in UI:
# 1. Get token: terraform output -raw nomad_server_token
# 2. Open Nomad UI and click "ACL Tokens"
# 3. Paste the token
```

### Getting Help

1. **Quick Token Setup**: Run `./scripts/get-tokens.sh`
2. **Check Service Status**: SSH to server and run `systemctl status consul nomad`
3. **View Logs**: `sudo journalctl -u consul -f` and `sudo journalctl -u nomad -f`
4. **Verify Network**: Check GCP firewall rules in console
5. **Test Connectivity**: `curl http://<server-ip>:8500/v1/status/leader`

## 📚 Documentation

- [Architecture Overview](docs/architecture.md)
- [Deployment Guide](docs/deployment.md)  
- [Troubleshooting](docs/troubleshooting.md)
- [Terraform README](terraform/README.md)
- [Packer README](packer/README.md)
- [Jobs README](nomad-jobs/README.md)

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make changes with tests
4. Submit a pull request

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🆘 Support

- **Issues**: GitHub Issues for bugs and feature requests
- **Discussions**: GitHub Discussions for questions
- **Documentation**: See `docs/` directory for detailed guides