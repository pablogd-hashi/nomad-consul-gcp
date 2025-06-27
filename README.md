# HashiStack Terramino Deployment

This repository contains Terraform configuration to deploy a complete HashiCorp stack on Google Cloud Platform (GCP) running the Terramino game application along with monitoring tools.

## Architecture

- **3 Nomad/Consul Servers**: Combined server nodes running both Consul and Nomad in server mode
- **2 Nomad Clients**: Worker nodes where applications are deployed
- **1 GCP Load Balancer**: Routes traffic to applications
- **Applications**: Terramino (Tetris game), Grafana, Prometheus
- **Service Mesh**: Consul Connect for secure service communication
- **API Gateway**: Traefik for internal routing
- **Workload Identity**: GCP service account integration

## Prerequisites

1. **GCP Account** with billing enabled
2. **Terraform Cloud** account with workspace configured
3. **HashiCorp Enterprise Licenses** for Consul and Nomad
4. **Domain Name** (optional, for SSL certificates)

## Setup Instructions

### 1. Prepare Your Environment

```bash
# Clone this repository
git clone <your-repo-url>
cd hashistack-terramino

# Copy the example variables file
cp terraform.tfvars.example terraform.tfvars
```

### 2. Configure Variables

Edit `terraform.tfvars` and fill in your values:

```hcl
# Required: Your GCP project ID
project_id = "your-gcp-project-id"

# Required: HashiCorp Enterprise licenses
consul_license = "your-consul-enterprise-license"
nomad_license  = "your-nomad-enterprise-license"

# Required: Your SSH public key for instance access
ssh_public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQC..."

# Optional: Customize other settings as needed
region = "us-central1"
zone   = "us-central1-a"
domain_name = "hashistack.local"
```

### 3. Deploy Infrastructure

```bash
# Initialize Terraform
terraform init

# Plan the deployment
terraform plan

# Apply the configuration
terraform apply
```

The deployment takes approximately 10-15 minutes to complete.

### 4. Verify Deployment

After deployment, you'll receive outputs with:

- Load balancer IP address
- Consul/Nomad UI URLs
- SSH commands for each instance
- ACL tokens (marked as sensitive)

```bash
# View all outputs
terraform output

# View sensitive outputs (ACL tokens)
terraform output -json | jq '.consul_master_token.value'
terraform output -json | jq '.nomad_server_token.value'
```

### 5. Deploy Applications

SSH into one of the Nomad servers and deploy the jobs:

```bash
# SSH to server-1
ssh ubuntu@<server-1-public-ip>

# Set environment variables
export NOMAD_ADDR=http://localhost:4646
export CONSUL_HTTP_ADDR=http://localhost:8500

# If ACLs are enabled, set tokens
export NOMAD_TOKEN=<nomad-server-token>
export CONSUL_HTTP_TOKEN=<consul-master-token>

# Deploy Traefik (API Gateway)
nomad job run /path/to/jobs/traefik.nomad.hcl

# Deploy Prometheus
nomad job run /path/to/jobs/prometheus.nomad.hcl

# Deploy Grafana
nomad job run /path/to/jobs/grafana.nomad.hcl

# Deploy Terramino
nomad job run /path/to/jobs/terramino.nomad.hcl
```

### 6. Access Applications

#### Via Load Balancer (if domain configured):
- **Terramino**: http://terramino.hashistack.local
- **Grafana**: http://grafana.hashistack.local (admin/admin)
- **Prometheus**: http://prometheus.hashistack.local

#### Direct Access via Server IPs:
- **Consul UI**: http://<server-ip>:8500
- **Nomad UI**: http://<server-ip>:4646
- **Traefik Dashboard**: http://<client-ip>:8080

### 7. DNS Configuration (Optional)

For domain-based routing, configure your DNS:

```
terramino.hashistack.local   A   <load-balancer-ip>
grafana.hashistack.local     A   <load-balancer-ip>
prometheus.hashistack.local  A   <load-balancer-ip>
```

Or add to your local `/etc/hosts` file:

```
<load-balancer-ip> terramino.hashistack.local
<load-balancer-ip> grafana.hashistack.local
<load-balancer-ip> prometheus.hashistack.local
```

## Architecture Details

### Security Features

- **ACLs Enabled**: Both Consul and Nomad have ACL systems enabled with secure token-based authentication
- **TLS Encryption**: All inter-service communication is encrypted using TLS
- **Workload Identity**: GCP service accounts provide secure authentication for workloads
- **Firewall Rules**: Restrictive firewall rules allowing only necessary ports

### High Availability

- **3-Server Cluster**: Consul and Nomad servers form a 3-node cluster for high availability
- **Load Balancing**: GCP Load Balancer distributes traffic across multiple client nodes
- **Health Checks**: Comprehensive health checking for all services
- **Auto-Recovery**: Services automatically restart on failure

### Monitoring & Observability

- **Prometheus**: Metrics collection from all HashiStack components
- **Grafana**: Visualization and dashboarding
- **Telemetry**: Comprehensive telemetry configuration for all services
- **Centralized Logging**: Structured logging with rotation

### Service Mesh

- **Consul Connect**: Provides secure service-to-service communication
- **Sidecar Proxies**: Automatic proxy injection for service mesh capabilities
- **Traffic Management**: Advanced routing and traffic policies

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

2. **ACL token issues**:
   ```bash
   # Bootstrap Consul ACLs (only on first server)
   consul acl bootstrap
   
   # Bootstrap Nomad ACLs
   nomad acl bootstrap
   ```

3. **Certificate issues**:
   ```bash
   # Regenerate certificates
   consul tls cert create -server -dc dc1
   nomad tls cert create -server
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
```

## Cleanup

To destroy all resources:

```bash
terraform destroy
```

**Warning**: This will permanently delete all infrastructure and data.

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test the deployment
5. Submit a pull request

## License

This project is licensed under the MIT License - see the LICENSE file for details.