# GKE Southwest Cluster - Admin Partition Integration

This directory contains the configuration for deploying a GKE cluster in Europe Southwest region as part of the multi-region admin partition strategy.

## Overview

- **Region**: `europe-southwest1`
- **Admin Partition**: `k8s-southwest`
- **Cluster Name**: `gke-southwest`
- **Purpose**: Secondary region for testing, acceptance, and disaster recovery
- **Network**: `10.20.0.0/24` (pods: `10.21.0.0/16`, services: `10.22.0.0/16`)

## Multi-Region Strategy

### Admin Partition Architecture
```
Europe Southwest1 (k8s-southwest partition)
├── DTAP Environments:
│   ├── backend-test         # Testing environment
│   ├── backend-acceptance   # Acceptance environment  
│   ├── backend-prod         # Production environment
│   ├── data-test           # Data services testing
│   ├── data-acceptance     # Data services acceptance
│   └── data-prod           # Data services production
└── Cross-partition communication with k8s-west
```

### Regional Responsibilities
| Component | Europe West1 (k8s-west) | Europe Southwest1 (k8s-southwest) |
|-----------|-------------------------|-----------------------------------|
| **Frontend** | ✅ Primary | 🔄 Failover |
| **API Gateway** | ✅ Primary | 🔄 Failover |
| **Backend Services** | 🔄 Failover | ✅ Primary |
| **Data Services** | 🔄 Failover | ✅ Primary |
| **Monitoring** | ✅ Primary | 📊 Regional |

## Quick Start

### 1. Deploy the Infrastructure

```bash
# Use task runner for streamlined deployment
task deploy-gke-southwest

# Or deploy manually
cd clusters/gke-southwest/terraform
terraform init && terraform apply
```

### 2. Configure kubectl Access

```bash
# Authenticate with the cluster
task gke-sw-auth

# Verify cluster access
kubectl get nodes
kubectl config current-context
```

### 3. Setup Admin Partition and Consul

#### Step 3.1: Prepare Environment
```bash
# Set up environment variables
export CONSUL_ENT_LICENSE="your-enterprise-license"
export CONSUL_BOOTSTRAP_TOKEN="bootstrap-token-from-dc1"

# Copy CA certificates from DC1 cluster
cp clusters/dc1/terraform/consul-agent-ca*.pem clusters/gke-southwest/manifests/
```

#### Step 3.2: Create Admin Partition
```bash
# Connect to DC1 Consul server and create the partition
export CONSUL_HTTP_ADDR="http://<dc1-server-ip>:8500"
export CONSUL_HTTP_TOKEN="<bootstrap-token>"

consul partition create -name k8s-southwest -description "Europe Southwest1 GKE Partition"

# Create partition token
consul acl token create \
  -description "k8s-southwest partition token" \
  -partition k8s-southwest \
  -policy-name admin-policy
```

#### Step 3.3: Setup Kubernetes Secrets
```bash
cd clusters/gke-southwest/manifests

# Run the setup script
./setup-secrets-southwest.sh

# Update the Helm values with actual server IPs
# Edit gke-consul-values-southwest.yaml:
# - Replace <dc1-consul-server-ip-*> with actual IPs
# - Replace <gke-southwest-api-endpoint> with cluster endpoint
```

#### Step 3.4: Deploy Consul
```bash
# Deploy Consul with southwest partition configuration
helm repo add hashicorp https://helm.releases.hashicorp.com
helm repo update

helm install consul hashicorp/consul \
  --namespace consul \
  --values gke-consul-values-southwest.yaml

# Verify deployment
kubectl get pods -n consul
kubectl get svc -n consul
```

### 4. Setup DTAP Environments

```bash
# Create environment-specific namespaces
kubectl create namespace backend-test
kubectl create namespace backend-acceptance
kubectl create namespace backend-prod
kubectl create namespace data-test
kubectl create namespace data-acceptance
kubectl create namespace data-prod

# Label namespaces for Consul injection
kubectl label namespace backend-test consul.hashicorp.com/connect-inject=true
kubectl label namespace backend-acceptance consul.hashicorp.com/connect-inject=true
kubectl label namespace backend-prod consul.hashicorp.com/connect-inject=true
kubectl label namespace data-test consul.hashicorp.com/connect-inject=true
kubectl label namespace data-acceptance consul.hashicorp.com/connect-inject=true
kubectl label namespace data-prod consul.hashicorp.com/connect-inject=true
```

## Configuration Details

### Network Configuration
- **VPC**: `gke-southwest-gke-network` (isolated from west1)
- **Subnet**: `gke-southwest-gke-subnet` (10.20.0.0/24)
- **Pod CIDR**: 10.21.0.0/16 (non-overlapping with west1)
- **Service CIDR**: 10.22.0.0/16 (non-overlapping with west1)
- **Master CIDR**: 172.17.0.0/28

### Admin Partition Features
- ✅ **External Consul servers** (DC1/DC2 connection)
- ✅ **Cross-partition mesh gateways** for west ↔ southwest communication
- ✅ **Consul Connect** service mesh
- ✅ **Enterprise namespaces** with DTAP separation
- ✅ **ACL policies** per partition
- ✅ **TLS encryption** end-to-end

## Cross-Partition Communication

### Service Discovery Examples

#### Access West1 Services from Southwest1:
```yaml
# In k8s-southwest, connect to k8s-west frontend
apiVersion: v1
kind: Service
metadata:
  name: frontend-proxy
  annotations:
    consul.hashicorp.com/connect-service-upstreams: "frontend.frontend-prod.k8s-west:9090"
spec:
  ports:
  - port: 9090
    targetPort: 9090
```

#### Access Southwest1 Services from West1:
```yaml
# In k8s-west, connect to k8s-southwest backend
apiVersion: v1
kind: Service
metadata:
  name: backend-proxy
  annotations:
    consul.hashicorp.com/connect-service-upstreams: "backend-service.backend-prod.k8s-southwest:8080"
spec:
  ports:
  - port: 8080
    targetPort: 8080
```

## Verification and Testing

### Partition Status
```bash
# Check partition registration
consul partition list

# Verify services in southwest partition
consul catalog services -partition k8s-southwest

# Check mesh gateway connectivity
kubectl get svc consul-mesh-gateway -n consul
```

### Cross-Partition Connectivity
```bash
# Test connection from southwest to west
kubectl exec -n backend-prod deployment/backend -- \
  curl -s http://frontend.frontend-prod.k8s-west.consul:9090/health

# Test connection from west to southwest  
kubectl exec -n frontend-prod deployment/frontend -- \
  curl -s http://backend-service.backend-prod.k8s-southwest.consul:8080/health
```

## File Structure

```
clusters/gke-southwest/
├── terraform/                           # Infrastructure as Code
│   ├── main.tf                         # GKE cluster configuration
│   ├── variables.tf                    # Region-specific variables
│   ├── outputs.tf                      # Cluster outputs
│   └── providers.tf                    # GCP provider
├── manifests/                          # Consul and app configurations (local only)
│   ├── gke-consul-values-southwest.yaml # Southwest partition Helm values
│   ├── setup-secrets-southwest.sh      # Secrets setup script
│   └── app-manifests/                  # Application deployments
│       ├── backend-test/               # Testing environment apps
│       ├── backend-acceptance/         # Acceptance environment apps
│       ├── backend-prod/               # Production environment apps
│       └── data-services/              # Data layer applications
└── README.md                           # This file
```

## Task Runner Commands

```bash
# Deployment
task deploy-gke-southwest          # Deploy GKE cluster
task gke-sw-auth                   # Authenticate kubectl
task status-gke-southwest          # Check cluster status

# Consul Management
task gke-sw-setup-secrets          # Setup Consul secrets
task gke-sw-deploy-consul          # Deploy Consul

# Cleanup
task destroy-gke-southwest         # Destroy cluster
```

## Terraform Cloud Workspace

- **Workspace**: `GKE-southwest`
- **Required Variables**:
  - `gcp_project`: Your GCP project ID
  - `gcp_sa`: Service account name  
  - `owner`: Your identifier

## Troubleshooting

### Common Issues

1. **Partition token authentication failure**
   ```bash
   # Verify partition token is correct
   consul acl token read -id <partition-token>
   ```

2. **Cross-partition connectivity issues**
   ```bash
   # Check mesh gateway status
   kubectl logs -n consul -l app=consul,component=mesh-gateway
   
   # Verify intentions are configured
   consul intention check frontend backend.backend-prod.k8s-southwest
   ```

3. **Secrets not found**
   ```bash
   # Verify all required secrets exist
   kubectl get secrets -n consul
   
   # Check CA certificate validity
   kubectl get secret consul-ca-cert -n consul -o yaml
   ```

## Next Steps

1. ✅ **Deploy southwest GKE cluster**
2. ✅ **Configure admin partition**
3. 🔄 **Deploy test applications to DTAP environments**
4. 🔄 **Setup cross-partition service communication**
5. 🔄 **Configure monitoring and observability**
6. 🔄 **Implement CI/CD pipelines for DTAP promotion**