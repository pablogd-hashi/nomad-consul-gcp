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
3. **HCP Account** for Packer images (optional, can use public images)
4. **Required APIs enabled**:
   ```bash
   gcloud services enable compute.googleapis.com
   gcloud services enable dns.googleapis.com
   gcloud services enable cloudresourcemanager.googleapis.com
   ```

### 1. Install Prerequisites

```bash
# Install Task runner
brew install go-task/tap/go-task  # macOS
# See docs/INSTALLATION.md for other platforms

# Install required tools: terraform, nomad, consul, jq, gcloud
```

### 2. Configure and Deploy

```bash
# Clone repository
git clone <repository-url>
cd nomad-consul-terramino

# Configure Terraform variables
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
# Edit terraform.tfvars with your values

# See available commands
task

# Deploy infrastructure
task provision

# Deploy monitoring (Grafana, Prometheus, Traefik)
task observability

# Deploy applications (Terramino game)
task apps
```

### 3. Access Your Environment

```bash
# Get access tokens
task tokens

# Get all URLs
task urls

# Check system status
task status
```

## 📁 Repository Structure

```
├── terraform/           # Infrastructure as Code
│   ├── main.tf          # Core resources
│   ├── variables.tf     # Input variables  
│   └── outputs.tf       # Tokens and URLs
├── packer/              # Custom image builds
│   ├── builds/          # Packer configurations
│   ├── scripts/         # Provisioning scripts
│   └── configs/         # Service configurations
├── nomad-jobs/          # Application deployments
│   ├── core/           # Infrastructure services
│   └── applications/   # Application workloads
├── scripts/            # Automation utilities
└── docs/              # Documentation
```

## 🔐 Security & Access

### Authentication

All services use ACL tokens generated automatically by Terraform:

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
```

### CLI Access

```bash
# Consul CLI
export CONSUL_HTTP_ADDR=http://<server-ip>:8500
export CONSUL_HTTP_TOKEN=<consul-token>
consul members

# Nomad CLI
export NOMAD_ADDR=http://<server-ip>:4646  
export NOMAD_TOKEN=<nomad-token>
nomad node status
```

## 🔧 Configuration

### Terraform Variables

Key variables to configure in `terraform/terraform.tfvars`:

```hcl
# Required
project_id     = "your-gcp-project"
gcp_sa         = "your-service-account@project.iam.gserviceaccount.com"
ssh_public_key = "ssh-rsa AAAAB3NzaC1yc2E..."
consul_license = "02MV4UU43BK5..."
nomad_license  = "02MV4UU43BK5..."

# Optional
region             = "us-central1"
machine_type_server = "e2-standard-2"
machine_type_client = "e2-standard-4"
cluster_name       = "my-hashistack"
```

### Environment-Specific Deployments

Use Terraform workspaces or separate directories:

```bash
# Development
cd terraform/environments/dev/
terraform init
terraform apply

# Production  
cd terraform/environments/prod/
terraform apply
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

## 🛠️ Development

### Building Custom Images

```bash
cd packer/builds/
packer build -var-file=../variables/common.pkrvars.hcl hashistack-server.pkr.hcl
```

### Testing Changes

```bash
# Run all validation tests
task test:all

# Individual tests
task test:terraform  # Terraform validation
task test:packer     # Packer validation  
task test:jobs       # Nomad job validation
```

### Task Commands

```bash
# Main workflow
task provision       # Deploy all infrastructure
task observability   # Deploy monitoring stack 
task apps            # Deploy applications
task destroy         # Destroy everything

# Image building
task build-server    # Build server image with Packer
task build-client    # Build client image with Packer

# Information
task tokens          # Get access tokens
task urls            # Get all URLs
task status          # Check system status
```

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