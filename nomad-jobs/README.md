# Nomad Job Definitions

This directory contains Nomad job definitions for deploying applications and services.

## Quick Start

```bash
# Set Nomad environment variables
export NOMAD_ADDR=http://<nomad-server-ip>:4646
export NOMAD_TOKEN=<nomad-token>

# Deploy core infrastructure
nomad job run core/traefik.nomad.hcl
nomad job run core/prometheus.nomad.hcl  
nomad job run core/grafana.nomad.hcl

# Deploy applications
nomad job run applications/terramino.nomad.hcl
```

## Directory Structure

- `core/` - Core infrastructure services (load balancer, monitoring)
- `applications/` - Application workloads
- `templates/` - Reusable job templates

## Core Services

### Traefik (`core/traefik.nomad.hcl`)
- API Gateway and Load Balancer
- Automatic service discovery with Consul
- HTTP routing and SSL termination
- Dashboard on port 8080

### Prometheus (`core/prometheus.nomad.hcl`)
- Metrics collection and storage
- Consul and Nomad metrics integration
- Web UI on port 9090
- Data persistence via host volumes

### Grafana (`core/grafana.nomad.hcl`)
- Monitoring dashboards and visualization
- Pre-configured Prometheus data source
- Web UI on port 3000 (admin/admin)
- Data persistence via host volumes

## Applications

### Terramino (`applications/terramino.nomad.hcl`)
- Tetris-like demo game
- Demonstrates container deployment
- Service registration with Consul
- Load balancer integration

## Job Templates

### Web Application (`templates/webapp.nomad.hcl.tpl`)
- Generic web application template
- Configurable via template variables
- Consul service registration
- Health checks and rolling updates

## Deployment Order

1. **Core Infrastructure** (can run in parallel):
   - Traefik (load balancer)
   - Prometheus (monitoring) 
   - Grafana (dashboards)

2. **Applications** (after core is healthy):
   - Terramino or other apps

## Service Discovery

All services automatically register with Consul and are discoverable via:
- **DNS**: `<service-name>.service.consul`
- **HTTP API**: `http://consul:8500/v1/catalog/services`
- **Traefik**: Automatic HTTP routing