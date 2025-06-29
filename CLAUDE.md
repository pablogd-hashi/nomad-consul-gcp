# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a HashiCorp infrastructure deployment project that creates a complete production-ready HashiCorp ecosystem on Google Cloud Platform (GCP). The project deploys Consul Enterprise, Nomad Enterprise, and the Terramino game application with monitoring (Prometheus/Grafana) and load balancing (Traefik/GCP LB).

## Key Technologies
- **Infrastructure**: Terraform for GCP deployment
- **HashiCorp Stack**: Consul Enterprise 1.17.0+ent, Nomad Enterprise 1.7.2+ent
- **Containerization**: Docker with Nomad orchestration
- **Load Balancing**: Traefik v3.0 + GCP HTTP Load Balancer
- **Monitoring**: Prometheus + Grafana
- **Security**: Enterprise ACLs, TLS encryption, service mesh

## Architecture

- **3 Server Nodes**: Combined Consul/Nomad servers (e2-standard-2)
- **2 Client Nodes**: Nomad workers for applications (e2-standard-4)
- **1 GCP Load Balancer**: Global HTTP load balancer with DNS
- **Service Mesh**: Consul Connect for secure service communication
- **Enterprise Security**: ACLs enabled, TLS encryption, firewall rules

## File Structure

### Terraform Configuration
- `main.tf` - Core infrastructure (VPC, networking, firewall, certificates, tokens)
- `servers.tf` - Consul/Nomad server instances with startup scripts
- `clients.tf` - Nomad client instances with startup scripts
- `load_balancer.tf` - GCP HTTP load balancer, DNS records, health checks
- `variables.tf` - Input variables and defaults
- `outputs.tf` - Infrastructure outputs (IPs, URLs, tokens, SSH commands)
- `terraform.tfvars.example` - Example configuration

### Application Jobs
- `jobs/terramino.nomad.hcl` - Tetris game application
- `jobs/traefik.nomad.hcl` - API gateway and load balancer
- `jobs/prometheus.nomad.hcl` - Metrics collection
- `jobs/grafana.nomad.hcl` - Monitoring dashboard
- `jobs/consul-connect-proxy.nomad.hcl` - Service mesh proxy

### Scripts
- `scripts/server-startup.sh` - Server node initialization
- `scripts/client-startup.sh` - Client node initialization
- `scripts/deploy-jobs.sh` - Automated job deployment
- `scripts/debug-server-startup.sh` - Debug server startup

## Common Development Commands

### Terraform Operations
```bash
# Plan infrastructure changes
terraform plan

# Apply infrastructure changes
terraform apply

# View outputs (including sensitive tokens)
terraform output
terraform output -json | jq '.consul_master_token.value'
terraform output -json | jq '.nomad_server_token.value'

# Destroy infrastructure
terraform destroy
```

### SSH Access
```bash
# SSH to server-1
export SERVER_IP=$(terraform output -json | jq -r '.consul_servers.value."server-1".public_ip')
ssh ubuntu@$SERVER_IP

# SSH to client-1
export CLIENT_IP=$(terraform output -json | jq -r '.nomad_clients.value."client-1".public_ip')
ssh ubuntu@$CLIENT_IP
```

### Nomad Job Management
```bash
# Deploy jobs (run on server node)
export NOMAD_ADDR=http://localhost:4646
export NOMAD_TOKEN="<from terraform output>"
nomad job run jobs/traefik.nomad.hcl
nomad job run jobs/terramino.nomad.hcl

# Check job status
nomad job status
nomad job status terramino
nomad alloc status <alloc-id>

# View logs
nomad alloc logs <alloc-id>
nomad alloc logs -f <alloc-id>
```

### Consul Operations
```bash
# Check cluster status
export CONSUL_HTTP_ADDR=http://localhost:8500
export CONSUL_HTTP_TOKEN="<from terraform output>"
consul members
consul catalog services
consul catalog nodes
```

### System Status Checks
```bash
# Check HashiCorp services
sudo systemctl status consul
sudo systemctl status nomad
sudo journalctl -u consul -f
sudo journalctl -u nomad -f

# Check cluster health
nomad server members
nomad node status
```

## Configuration Management

### Terraform Cloud Variables
The project uses three variable sets in Terraform Cloud:

1. **HashiStack Common** - Consul/Nomad licenses, versions, ACL settings
2. **GCP Common** - GCP credentials, machine types, networking
3. **Workspace Variables** - Project-specific settings (project_id, SSH keys, DNS)

### Enterprise Licensing
Requires valid Consul Enterprise and Nomad Enterprise licenses configured as sensitive variables in Terraform Cloud.

## Access Points

### Direct Access URLs
- **Consul UI**: `http://<server-ip>:8500`
- **Nomad UI**: `http://<server-ip>:4646`  
- **Traefik Dashboard**: `http://<client-ip>:8080`
- **Grafana**: `http://<client-ip>:3000` (admin/admin)
- **Prometheus**: `http://<client-ip>:9090`

### Load Balancer Access (if DNS configured)
- **Terramino**: `http://terramino-<cluster-name>.<domain>`
- **Grafana**: `http://grafana-<cluster-name>.<domain>`
- **Prometheus**: `http://prometheus-<cluster-name>.<domain>`

## Security Considerations

- Enterprise ACLs are enabled by default
- TLS encryption is configured for all HashiCorp services
- Firewall rules restrict access to necessary ports only
- Uses existing GCP service account (not creating new ones)
- Enterprise licenses and tokens are handled as sensitive variables

## High-Level Architecture Flow

1. **Infrastructure**: Terraform creates GCP VPC, firewall rules, compute instances
2. **Bootstrap**: Startup scripts install and configure Consul/Nomad with Enterprise licenses
3. **Clustering**: 3-server cluster formation with automatic leader election
4. **Applications**: Nomad jobs deploy containerized applications to client nodes
5. **Load Balancing**: Traefik routes internal traffic, GCP LB handles external traffic
6. **Service Discovery**: Consul provides service registration and health checking
7. **Monitoring**: Prometheus collects metrics, Grafana provides visualization

## Testing and Validation

No automated testing framework is configured. Validation is done through:
- Terraform plan/apply success
- Service health checks (systemctl status)
- Cluster membership verification (consul members, nomad server members)
- Application deployment success (nomad job status)
- HTTP endpoint accessibility