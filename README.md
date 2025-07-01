# HashiCorp Consul + Nomad on GCP

A production-ready deployment of Consul Enterprise and Nomad Enterprise on Google Cloud Platform. Gets you a working cluster with monitoring, service mesh, and load balancing.

## What you get

- **3 servers** running both Consul and Nomad (combined setup saves resources)
- **2 clients** for running your applications 
- **Automatic TLS** between all nodes using Consul's auto-encrypt
- **ACLs enabled** with proper tokens for security
- **DNS setup** so you can access services via nice URLs instead of IP addresses
- **Monitoring** with Prometheus + Grafana + pre-built Nomad dashboard
- **Service mesh** with Consul Connect for secure service-to-service communication

## Quick start

```bash
# 1. Configure your settings
cd terraform/
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your GCP project, SSH key, and enterprise licenses

# 2. Deploy infrastructure
terraform apply

# 3. Deploy applications using the Taskfile
task deploy-with-monitoring
```

## Folder structure

### `/terraform/`
The main infrastructure code that creates everything in GCP.

- **`main.tf`** - Core networking (VPC, subnets, firewall rules) and certificates
- **`servers.tf`** - The 3 server nodes that run both Consul and Nomad
- **`clients.tf`** - The 2 client nodes that just run Nomad for applications
- **`load_balancer.tf`** - GCP load balancer + DNS records for external access
- **`template.tpl`** - Startup script for servers (installs/configures Consul+Nomad)
- **`template-client.tpl`** - Startup script for clients (installs/configures Nomad only)

### `/nomad-jobs/`
Application deployments that run on the Nomad cluster.

#### `/nomad-jobs/core/`
Essential services that make everything work:

- **`traefik.nomad.hcl`** - Load balancer/API gateway (deploy this first)
- **`prometheus.nomad.hcl`** - Metrics collection (scrapes Nomad/Consul metrics)
- **`grafana.nomad.hcl`** - Monitoring dashboard (auto-loads Nomad dashboard)

#### `/nomad-jobs/applications/`
Your actual applications:

- **`terramino.nomad.hcl`** - Demo Tetris game to test everything works

### `/terraform/Taskfile.yml`
Deployment automation with proper ordering:

- **`task deploy-minimal`** - Just infrastructure + Traefik
- **`task deploy-with-monitoring`** - Infrastructure + Traefik + monitoring stack
- **`task deploy-all`** - Everything including demo apps

## Why the configuration is this way

### Combined server nodes
Runs both Consul and Nomad on the same 3 servers instead of separate clusters. This:
- Saves money (fewer VMs)
- Simplifies networking (services can talk locally)
- Reduces operational complexity
- Still provides HA with leader election

### Auto-encrypt TLS
Uses Consul's auto-encrypt feature instead of managing certificates manually:
- Servers have full certs and act as CA
- Clients get certs automatically from servers
- No manual certificate distribution needed
- Automatic rotation

### Bridge networking
All applications use bridge networking with static ports because:
- Simpler than host networking
- Works with service discovery
- Allows port mapping flexibility
- Compatible with service mesh

### Template files for configuration
The `.tpl` files generate different configs for servers vs clients:
- Servers: Full Consul config + Nomad server mode
- Clients: Basic Consul config + Nomad client mode
- Keeps the configs DRY but allows customization

### Static DNS records
Points DNS to client node IPs (not load balancer) because:
- Services run on clients, not the load balancer
- Direct access is faster
- Simpler routing (no extra hop)
- Load balancer is for external HTTP traffic only

### Prometheus static targets
Uses static IP targets instead of service discovery because:
- More reliable in this setup
- Consul service discovery can be flaky with metrics endpoints
- Static IPs are predictable in this deployment
- Easier to troubleshoot

## Access your services

After deployment, use these DNS names (replace `<cluster-name>` and `<domain>` with your values):

- **Nomad UI**: `http://nomad-<cluster-name>.<domain>:4646`
- **Consul UI**: `http://consul-<cluster-name>.<domain>:8500`  
- **Grafana**: `http://grafana-<cluster-name>.<domain>`
- **Terramino**: `http://terramino-<cluster-name>.<domain>`

Get tokens with: `terraform output consul_master_token` and `terraform output nomad_server_token`

## Common commands

```bash
# Deploy with monitoring
task deploy-with-monitoring

# Check status of everything
task status

# View logs for a specific job
task logs JOB=grafana

# Restart a job
task restart JOB=prometheus

# Stop everything
task stop-all

# SSH to first server
ssh ubuntu@$(terraform output -json consul_servers | jq -r '.["server-1"].public_ip')
```

That's it. Clone, configure, deploy, and you have a working HashiCorp stack.