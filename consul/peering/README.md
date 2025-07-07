# Consul API Gateway and Cluster Peering Setup

This directory contains the configuration and automation scripts for setting up Consul API Gateway with cluster peering between HashiCorp Consul datacenters.

## Overview

This setup enables:
- **Consul API Gateway**: North-south traffic routing on port 8081 (separate from Traefik on 8080)
- **Cluster Peering**: Secure service communication between DC1 and DC2
- **Demo Applications**: Frontend and backend services demonstrating cross-datacenter connectivity
- **Service Mesh**: Consul Connect with transparent proxy for secure service-to-service communication

## Architecture

```
┌─────────────────┐    ┌─────────────────┐
│       DC1       │    │       DC2       │
│                 │    │                 │
│ API Gateway     │    │ External Nginx  │
│ (port 8081)     │◄──►│ (via peering)   │
│                 │    │                 │
│ Frontend        │    │ Private API     │
│ Public API      │    │ (peered)        │
│ Private API     │    │                 │
└─────────────────┘    └─────────────────┘
```

## Prerequisites

1. **HashiCorp Stack**: Consul Enterprise 1.21.0+ent and Nomad Enterprise 1.10.0+ent deployed
2. **ACLs Enabled**: Both clusters must have ACL system enabled
3. **Network Connectivity**: Clusters must be able to communicate over the network
4. **CLI Tools**: `consul`, `nomad`, and `task` commands available
5. **Environment Variables**: 
   - `CONSUL_HTTP_ADDR` (defaults to http://localhost:8500)
   - `CONSUL_HTTP_TOKEN` (required for ACL operations)
   - `NOMAD_ADDR` (defaults to http://localhost:4646)
   - `NOMAD_TOKEN` (required for namespace operations)

## Directory Structure

```
consul/peering/
├── README.md                           # This documentation
├── Taskfile.yml                        # Task automation
├── configs/
│   ├── api-gateway/
│   │   ├── listener.hcl                # API Gateway configuration
│   │   └── httproute.hcl               # HTTP routing rules
│   ├── proxy-defaults.hcl              # Global proxy settings
│   ├── private-api-intentions.hcl      # Private API access rules
│   ├── public-api-intentions.hcl       # Public API access rules
│   └── front-intentions.hcl            # Frontend service intentions
└── ../nomad-apps/
    ├── api-gw.nomad/
    │   └── api-gw.nomad.hcl            # API Gateway Nomad job
    └── demo-fake-service/
        ├── backend.nomad.hcl           # Backend services job
        └── frontend.nomad.hcl          # Frontend service job
```

## Quick Start

### 1. Complete Deployment (All Steps)

Run the full deployment on DC1:

```bash
# Set environment variables
export CONSUL_HTTP_ADDR="http://localhost:8500"
export CONSUL_HTTP_TOKEN="your-consul-master-token"
export NOMAD_ADDR="http://localhost:4646"
export NOMAD_TOKEN="your-nomad-token"

# Deploy everything
task full-deployment
```

### 2. Step-by-Step Deployment

For more control, run individual steps:

```bash
# 1. Setup prerequisites
task setup-prerequisites

# 2. Deploy API Gateway
task deploy-gateway-stack

# 3. Deploy demo applications
task deploy-demo-apps

# 4. Verify deployment
task status
task test-api-gateway
```

## Detailed Setup Instructions

### Phase 1: Prerequisites Setup

#### Create Nomad Namespace
```bash
task setup-namespace
```
Creates the `ingress` namespace for API Gateway workloads with proper ACL isolation.

#### Configure Consul ACL Binding Rules
```bash
task setup-acl
```
Sets up ACL binding rule that allows Nomad workloads in the `ingress` namespace to assume the `builtin/api-gateway` policy.

#### Apply Proxy Defaults
```bash
task setup-proxy-defaults
```
Configures global proxy settings for Consul Connect service mesh.

#### Setup Service Intentions
```bash
task setup-intentions
```
Applies default service intentions for backend API access control.

### Phase 2: API Gateway Deployment

#### Deploy API Gateway Job
```bash
task deploy-api-gateway
```
Deploys the API Gateway as a Nomad job in the `ingress` namespace on port 8081.

#### Configure Gateway Routing
```bash
task configure-gateway
```
Applies listener configuration and HTTP routing rules to the API Gateway.

#### Setup Frontend Intentions
```bash
task setup-frontend-intentions
```
Configures service intentions for frontend service access.

### Phase 3: Demo Applications

#### Deploy Backend Services
```bash
task deploy-demo-backend
```
Deploys public and private API services:
- **Public API**: Port 8082, accessible via API Gateway
- **Private API**: Port 8083, Connect-only access

#### Deploy Frontend Service
```bash
task deploy-demo-frontend
```
Deploys frontend service that connects to both APIs and demonstrates cross-datacenter connectivity.

### Phase 4: Cluster Peering Setup

#### Setup Peering from DC1
```bash
task setup-peering-dc1
```
Generates peering token and saves to `dc2-peering-token.txt`.

#### Establish Peering from DC2
```bash
# Copy token to DC2 cluster
scp dc2-peering-token.txt user@dc2-server:/path/to/peering/

# On DC2, establish peering
task setup-peering-dc2
```

#### Verify Peering
```bash
task verify-peering
```
Checks peering status and exported services configuration.

## Service Access Points

### API Gateway
- **URL**: http://localhost:8081
- **Routes**: All traffic routed to `front-service`
- **Protocol**: HTTP (no TLS termination)

### Demo Services (Direct Access)
- **Frontend**: Via API Gateway on port 8081
- **Public API**: Port 8082 (also via API Gateway)
- **Private API**: Port 8083 (Connect-only, not externally accessible)

### Service Discovery
All services are registered in Consul with appropriate tags:
- `front-service`: `web`, `frontend`
- `public-api`: `api`, `public`
- `private-api`: `api`, `private`

## Port Allocation

| Service | Port | Access | Protocol |
|---------|------|--------|----------|
| Traefik Dashboard | 8080 | External | HTTP |
| API Gateway | 8081 | External | HTTP |
| Public API | 8082 | Internal/Gateway | HTTP |
| Private API | 8083 | Connect-only | HTTP |

## Cross-Datacenter Communication

The frontend service demonstrates cross-datacenter connectivity with these upstream URIs:
- `http://public-api.virtual.consul:9090` (local DC)
- `http://private-api.virtual.consul:9090` (local DC)
- `http://private-api.virtual.gcp-dc2-default.peer.consul:9090` (peered DC)

## Troubleshooting

### Check Service Status
```bash
task status
```

### Test API Gateway
```bash
task test-api-gateway
curl -s http://localhost:8081
```

### Check Nomad Job Logs
```bash
nomad alloc logs -f $(nomad job allocs my-api-gateway | grep running | awk '{print $1}')
```

### Check Consul Service Health
```bash
consul catalog services
consul health service front-service
```

### Verify Peering Connection
```bash
consul peering list
consul catalog services -peer dc1-peering
```

### Common Issues

1. **API Gateway not accessible**: Check Nomad job status and port allocation
2. **Services not registering**: Verify Consul Connect sidecar deployment
3. **Cross-DC communication failing**: Check peering status and exported services
4. **ACL denials**: Verify workload identity and binding rules

## Cleanup

### Remove All Resources
```bash
task full-cleanup
```

### Partial Cleanup
```bash
# Remove jobs only
task cleanup-jobs

# Remove Consul configurations only
task cleanup-configs

# Remove namespace only
task cleanup-namespace
```

## Configuration Files

### API Gateway Listener (`configs/api-gateway/listener.hcl`)
Configures the API Gateway to listen on port 8081 with HTTP protocol.

### HTTP Route (`configs/api-gateway/httproute.hcl`)
Routes all traffic from the API Gateway to the `front-service`.

### Service Intentions
- **Front Intentions**: Allow API Gateway to communicate with frontend
- **Private API Intentions**: Restrict access to private API endpoints
- **Public API Intentions**: Allow broader access to public API endpoints

## Security Considerations

- API Gateway runs in dedicated `ingress` namespace with restricted ACL permissions
- Service mesh encryption via Consul Connect transparent proxy
- Service intentions enforce access control between services
- Cross-datacenter communication secured via cluster peering
- No direct external access to backend APIs (only via API Gateway)

## Next Steps

1. **Configure TLS**: Add TLS termination to API Gateway for production
2. **Custom Routes**: Add more sophisticated routing rules in `httproute.hcl`
3. **Load Balancing**: Configure upstream load balancing for backend services
4. **Monitoring**: Integrate with Prometheus/Grafana for API Gateway metrics
5. **Exported Services**: Configure service exports for cross-datacenter access