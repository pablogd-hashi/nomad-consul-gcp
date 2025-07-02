# HashiCorp Enterprise Stack on GCP

A production-ready deployment of HashiCorp Consul Enterprise, Nomad Enterprise, and supporting applications on Google Cloud Platform with comprehensive monitoring, load balancing, and enterprise security features.

## 🏗️ Architecture Overview

This project deploys a complete HashiCorp ecosystem with:

- **3 Server Nodes**: Combined Consul/Nomad servers with enterprise licenses (e2-standard-2)
- **2 Client Nodes**: Nomad workers for application workloads (e2-standard-4) 
- **Enterprise Security**: ACLs enabled, TLS encryption, service mesh with Consul Connect
- **Load Balancing**: Traefik v3.0 + GCP HTTP Load Balancer with DNS integration
- **Monitoring Stack**: Prometheus + Grafana with pre-configured dashboards
- **Infrastructure**: Managed instance groups, auto-healing, regional distribution

## 📋 Prerequisites

### Required Accounts & Licenses
- **GCP Project** with the following IAM roles:
  - `roles/owner` or `roles/editor`
  - `roles/iam.serviceAccountUser`
  - `roles/compute.admin`
  - `roles/dns.admin` (if using DNS zones)
- **HashiCorp Consul Enterprise License** (1.17.0+ent compatible)
- **HashiCorp Nomad Enterprise License** (1.7.2+ent compatible)

### Required Tools
- **Terraform CLI** v1.0+ or **HCP Terraform** access
- **HashiCorp Packer** for custom image building
- **gcloud CLI** configured with appropriate credentials

## 🛠️ Quick Start

### 1. Build Custom Images
```bash
cd packer/gcp
# Edit gcp/consul_gcp.auth.pkvars.hcl with your GCP project
packer build .
```

### 2. Configure Variables
Copy and edit the Terraform variables:
```bash
cp terraform.tfvars.example terraform.auto.tfvars
```

Required variables:
```hcl
gcp_region = "us-east2"
gcp_project = "your-gcp-project-id" 
gcp_sa = "your-service-account@project.iam.gserviceaccount.com"
cluster_name = "gcp-dc1"
owner = "your-alias"
consul_license = "02MV4UU43BK5HGYY..." # Your Consul Enterprise license
nomad_license = "02MV4UU43BK5HGYY..."  # Your Nomad Enterprise license
dns_zone = "your-dns-zone-name"        # Optional: for FQDN access
```

### 3. Deploy Infrastructure
```bash
cd terraform
terraform init
terraform plan
terraform apply
```

### 4. Configure Environment
```bash
# Set up local environment variables
eval "$(terraform output -raw environment_setup | grep 'bash_export' -A 10)"

# Verify cluster status
consul members
nomad server members
nomad node status
```

## 🌐 Access Points

### Via Load Balancer (with DNS)
- **Consul UI**: `https://consul-gcp-dc1.yourdomain.com`
- **Nomad UI**: `https://nomad-gcp-dc1.yourdomain.com`
- **Grafana**: `https://grafana-gcp-dc1.yourdomain.com` (admin/admin)
- **Traefik Dashboard**: `https://traefik-gcp-dc1.yourdomain.com`

### Direct Instance Access
```bash
# List instances and their IPs
terraform output quick_commands

# SSH to server nodes
ssh ubuntu@$(gcloud compute instances list --filter='name~hashi-server' --format='value(natIP)' --limit=1)

# SSH to client nodes  
ssh ubuntu@$(gcloud compute instances list --filter='name~hashi-clients' --format='value(natIP)' --limit=1)
```

## 🚀 Application Deployment

### Deploy Monitoring Stack
```bash
# SSH to any server node
export NOMAD_ADDR=http://localhost:4646
export NOMAD_TOKEN="$(terraform output -raw auth_tokens | jq -r '.nomad_token')"

# Deploy applications
nomad job run jobs/traefik.nomad.hcl
nomad job run jobs/prometheus.nomad.hcl  
nomad job run jobs/grafana.nomad.hcl
```

### Deploy Demo Applications
```bash
nomad job run jobs/terramino.nomad.hcl
nomad job status
```

## 🔧 Key Features

### Enterprise Security
- **ACL System**: Bootstrap tokens, fine-grained permissions
- **TLS Encryption**: All HashiCorp services encrypted in transit
- **Service Mesh**: Consul Connect for zero-trust networking
- **Firewall Rules**: Restricted access, internal communication secured

### High Availability
- **Instance Groups**: Auto-healing, rolling updates, zone distribution
- **Load Balancers**: Multi-tier (GCP Global + Traefik)
- **Health Checks**: Application and infrastructure monitoring
- **Backup Strategy**: Persistent disks, stateful configurations

### Monitoring & Observability
- **Prometheus**: Metrics collection from all HashiCorp services
- **Grafana**: Pre-configured dashboards for Consul, Nomad, and infrastructure
- **Traefik**: Request routing, load balancing, and traffic metrics
- **Logging**: Centralized via systemd journal

## 📊 Terraform Outputs

The deployment provides comprehensive outputs:

```bash
# View all outputs
terraform output

# Specific information
terraform output cluster_info          # Basic cluster details
terraform output hashistack_urls      # Consul/Nomad access URLs  
terraform output monitoring_urls      # Grafana/Prometheus URLs
terraform output server_nodes         # Server instance group info
terraform output client_nodes         # Client instance groups info
terraform output auth_tokens          # Enterprise tokens (sensitive)
terraform output quick_commands       # Useful management commands
```

## 🔐 Security Considerations

- **Enterprise Licenses**: Stored as sensitive Terraform variables
- **Bootstrap Tokens**: Auto-generated, marked sensitive in outputs
- **TLS Certificates**: Self-signed CA, server certificates auto-generated
- **Network Security**: VPC isolation, firewall rules, internal communication only
- **Access Control**: ACLs enabled by default, least-privilege principles

## 🛠️ Common Operations

### Cluster Management
```bash
# Check cluster health
consul members
nomad server members
nomad node status

# View job status
nomad job status
nomad alloc status <allocation-id>

# Scale applications
nomad job scale <job-name> <count>
```

### Troubleshooting
```bash
# Check service status on nodes
sudo systemctl status consul
sudo systemctl status nomad
sudo journalctl -u consul -f
sudo journalctl -u nomad -f

# View application logs
nomad alloc logs <allocation-id>
nomad alloc logs -f <allocation-id>
```

### Infrastructure Updates
```bash
# Update instance templates
terraform plan
terraform apply

# Rolling update (managed instance groups handle this automatically)
# Check status in GCP Console > Compute Engine > Instance Groups
```

## 📁 Project Structure

```
├── terraform/              # Infrastructure as Code
│   ├── main.tf             # Core networking, load balancers, DNS
│   ├── instances.tf        # Instance groups, templates, configs
│   ├── variables.tf        # Input variables
│   ├── outputs.tf          # Structured outputs
│   └── consul.tf           # Consul-specific resources
├── packer/                 # Custom image builds
│   └── gcp/               # GCP-specific Packer configs
├── jobs/                  # Nomad job definitions
│   ├── traefik.nomad.hcl  # Load balancer
│   ├── prometheus.nomad.hcl # Metrics collection
│   ├── grafana.nomad.hcl   # Monitoring dashboard
│   └── terramino.nomad.hcl # Demo application
├── scripts/               # Deployment automation
└── CLAUDE.md             # AI assistant instructions
```

## 🤝 Contributing

This is a demonstration repository. For production use:

1. Review and adapt security configurations
2. Implement proper backup strategies  
3. Configure monitoring alerts
4. Establish CI/CD pipelines
5. Review network security policies

## 📝 License

This project is for demonstration purposes. Ensure you have proper HashiCorp Enterprise licenses before deploying.

---

**Note**: This deployment creates billable GCP resources. Remember to run `terraform destroy` when done testing.