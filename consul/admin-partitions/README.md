# Admin Partitions Demo - Step-by-Step Deployment Guide

This guide provides a complete procedure for setting up Consul Enterprise admin partitions with multi-environment namespaces and demo applications.

## 🎯 Demo Architecture

```
Consul Servers (VMs) - Enterprise
├── Admin Partition: "k8s-west1" 
│   ├── Namespace: "development"
│   ├── Namespace: "testing" 
│   └── Namespace: "acceptance"
└── Admin Partition: "k8s-southwest1"
    ├── Namespace: "development"
    ├── Namespace: "testing"
    └── Namespace: "production"
```

## 📋 Infrastructure Overview

### Consul Servers
- **DC1**: HashiStack servers (europe-southwest1)
- **DC2**: HashiStack servers (europe-west1)
- **Enterprise License**: Required for admin partitions
- **ACLs**: Enabled with bootstrap token

### GKE Clusters
- **k8s-west1 partition**: GKE cluster (europe-west1)
- **k8s-southwest1 partition**: GKE cluster (europe-southwest1)

### Nomad API Gateways
- **DC1**: API Gateway for mesh ingress
- **DC2**: API Gateway for mesh ingress (to be deployed)

## 🔐 Prerequisites

1. **Consul Enterprise** running on VMs with admin partitions enabled
2. **Two GKE clusters** deployed and accessible
3. **Consul Enterprise License** available
4. **Bootstrap token** from Consul servers
5. **CA certificates** from Consul servers
6. **Nomad clusters** (DC1/DC2) with API gateways

## 📝 Step-by-Step Deployment Procedure

### Phase 1: Environment Setup and Validation

#### Step 1.1: Verify Consul Servers
```bash
# Connect to Consul servers
export CONSUL_HTTP_ADDR="http://<dc1-server-ip>:8500"
export CONSUL_HTTP_TOKEN="<bootstrap-token>"

# Verify cluster status
consul members
consul partition list
consul acl policy list
```

#### Step 1.2: Verify GKE Clusters
```bash
# Check both GKE clusters are accessible
kubectl config get-contexts | grep gke

# Test west1 cluster
kubectl config use-context <gke-west1-context>
kubectl get nodes

# Test southwest1 cluster  
kubectl config use-context <gke-southwest1-context>
kubectl get nodes
```

### Phase 2: ACL Policies and Roles

#### Step 2.1: Create Base Admin Partition Policies

**Policy 1: k8s-west1-admin-policy**
```bash
consul acl policy create \
  -name "k8s-west1-admin-policy" \
  -description "Admin policy for k8s-west1 partition" \
  -rules @consul/admin-partitions/policies/k8s-west1-admin-policy.hcl
```

**Policy 2: k8s-southwest1-admin-policy**
```bash
consul acl policy create \
  -name "k8s-southwest1-admin-policy" \
  -description "Admin policy for k8s-southwest1 partition" \
  -rules @consul/admin-partitions/policies/k8s-southwest1-admin-policy.hcl
```

#### Step 2.2: Create Environment-Specific Policies

**Development Environment Policies:**
```bash
# West1 Development
consul acl policy create \
  -name "k8s-west1-development-policy" \
  -description "Development environment policy for k8s-west1" \
  -rules @consul/admin-partitions/policies/k8s-west1-development-policy.hcl

# Southwest1 Development
consul acl policy create \
  -name "k8s-southwest1-development-policy" \
  -description "Development environment policy for k8s-southwest1" \
  -rules @consul/admin-partitions/policies/k8s-southwest1-development-policy.hcl
```

**Testing Environment Policies:**
```bash
# West1 Testing
consul acl policy create \
  -name "k8s-west1-testing-policy" \
  -description "Testing environment policy for k8s-west1" \
  -rules @consul/admin-partitions/policies/k8s-west1-testing-policy.hcl

# Southwest1 Testing
consul acl policy create \
  -name "k8s-southwest1-testing-policy" \
  -description "Testing environment policy for k8s-southwest1" \
  -rules @consul/admin-partitions/policies/k8s-southwest1-testing-policy.hcl
```

**Production/Acceptance Environment Policies:**
```bash
# West1 Acceptance
consul acl policy create \
  -name "k8s-west1-acceptance-policy" \
  -description "Acceptance environment policy for k8s-west1" \
  -rules @consul/admin-partitions/policies/k8s-west1-acceptance-policy.hcl

# Southwest1 Production
consul acl policy create \
  -name "k8s-southwest1-production-policy" \
  -description "Production environment policy for k8s-southwest1" \
  -rules @consul/admin-partitions/policies/k8s-southwest1-production-policy.hcl
```

#### Step 2.3: Create ACL Roles

**Admin Roles:**
```bash
# k8s-west1 admin role
consul acl role create \
  -name "k8s-west1-admin" \
  -description "Admin role for k8s-west1 partition" \
  -policy-name "k8s-west1-admin-policy"

# k8s-southwest1 admin role
consul acl role create \
  -name "k8s-southwest1-admin" \
  -description "Admin role for k8s-southwest1 partition" \
  -policy-name "k8s-southwest1-admin-policy"
```

**Environment-Specific Roles:**
```bash
# Development roles
consul acl role create \
  -name "k8s-west1-developer" \
  -description "Developer role for k8s-west1 development environment" \
  -policy-name "k8s-west1-development-policy"

consul acl role create \
  -name "k8s-southwest1-developer" \
  -description "Developer role for k8s-southwest1 development environment" \
  -policy-name "k8s-southwest1-development-policy"

# Testing roles
consul acl role create \
  -name "k8s-west1-tester" \
  -description "Tester role for k8s-west1 testing environment" \
  -policy-name "k8s-west1-testing-policy"

consul acl role create \
  -name "k8s-southwest1-tester" \
  -description "Tester role for k8s-southwest1 testing environment" \
  -policy-name "k8s-southwest1-testing-policy"

# Production/Acceptance roles
consul acl role create \
  -name "k8s-west1-acceptor" \
  -description "Acceptance role for k8s-west1 acceptance environment" \
  -policy-name "k8s-west1-acceptance-policy"

consul acl role create \
  -name "k8s-southwest1-operator" \
  -description "Production operator role for k8s-southwest1" \
  -policy-name "k8s-southwest1-production-policy"
```

### Phase 3: Admin Partitions Creation

#### Step 3.1: Create Admin Partitions
```bash
# Create k8s-west1 partition
consul partition create \
  -name "k8s-west1" \
  -description "Admin partition for GKE West1 cluster with dev/test/acceptance environments"

# Create k8s-southwest1 partition
consul partition create \
  -name "k8s-southwest1" \
  -description "Admin partition for GKE Southwest1 cluster with dev/test/production environments"

# Verify partitions
consul partition list
```

#### Step 3.2: Create Admin Partition Tokens
```bash
# Create k8s-west1 admin token
consul acl token create \
  -description "Admin token for k8s-west1 partition" \
  -partition "k8s-west1" \
  -role-name "k8s-west1-admin" | tee consul/admin-partitions/tokens/k8s-west1-admin-token.txt

# Create k8s-southwest1 admin token
consul acl token create \
  -description "Admin token for k8s-southwest1 partition" \
  -partition "k8s-southwest1" \
  -role-name "k8s-southwest1-admin" | tee consul/admin-partitions/tokens/k8s-southwest1-admin-token.txt

# Extract token IDs
cat consul/admin-partitions/tokens/k8s-west1-admin-token.txt | grep SecretID | awk '{print $2}' > consul/admin-partitions/tokens/k8s-west1-admin.token
cat consul/admin-partitions/tokens/k8s-southwest1-admin-token.txt | grep SecretID | awk '{print $2}' > consul/admin-partitions/tokens/k8s-southwest1-admin.token
```

### Phase 4: GKE Consul Deployment

#### Step 4.1: Setup Kubernetes Secrets (k8s-west1)
```bash
# Switch to k8s-west1 cluster context
kubectl config use-context <gke-west1-context>

# Create consul namespace
kubectl create namespace consul

# Create secrets
kubectl create secret generic consul-ent-license \
  --from-literal=key="$CONSUL_ENT_LICENSE" \
  -n consul

kubectl create secret generic consul-bootstrap-token \
  --from-literal=token="$(cat consul/admin-partitions/tokens/k8s-west1-admin.token)" \
  -n consul

# Copy CA certificates from Consul servers
kubectl create secret generic consul-ca-cert \
  --from-file=tls.crt=clusters/dc1/terraform/consul-agent-ca.pem \
  -n consul

kubectl create secret generic consul-ca-key \
  --from-file=tls.key=clusters/dc1/terraform/consul-agent-ca-key.pem \
  -n consul
```

#### Step 4.2: Setup Kubernetes Secrets (k8s-southwest1)
```bash
# Switch to k8s-southwest1 cluster context
kubectl config use-context <gke-southwest1-context>

# Create consul namespace
kubectl create namespace consul

# Create secrets (same process as west1)
kubectl create secret generic consul-ent-license \
  --from-literal=key="$CONSUL_ENT_LICENSE" \
  -n consul

kubectl create secret generic consul-bootstrap-token \
  --from-literal=token="$(cat consul/admin-partitions/tokens/k8s-southwest1-admin.token)" \
  -n consul

kubectl create secret generic consul-ca-cert \
  --from-file=tls.crt=clusters/dc1/terraform/consul-agent-ca.pem \
  -n consul

kubectl create secret generic consul-ca-key \
  --from-file=tls.key=clusters/dc1/terraform/consul-agent-ca-key.pem \
  -n consul
```

#### Step 4.3: Deploy Consul with Helm

**k8s-west1 cluster:**
```bash
# Switch context and populate values
kubectl config use-context <gke-west1-context>
cd clusters/gke-europe-west1/helm
./setup-values.sh

# Deploy Consul
helm repo add hashicorp https://helm.releases.hashicorp.com
helm repo update
helm install consul hashicorp/consul --namespace consul --values values.yaml

# Verify deployment
kubectl get pods -n consul
kubectl get svc -n consul
```

**k8s-southwest1 cluster:**
```bash
# Switch context and populate values
kubectl config use-context <gke-southwest1-context>
cd clusters/gke-southwest/helm
./setup-values.sh

# Deploy Consul
helm install consul hashicorp/consul --namespace consul --values values.yaml

# Verify deployment
kubectl get pods -n consul
kubectl get svc -n consul
```

### Phase 5: Environment Namespaces Setup

#### Step 5.1: Create k8s-west1 Environment Namespaces
```bash
kubectl config use-context <gke-west1-context>

# Create environment namespaces
kubectl create namespace development
kubectl create namespace testing
kubectl create namespace acceptance

# Label namespaces for Consul injection
kubectl label namespace development consul.hashicorp.com/connect-inject=true
kubectl label namespace testing consul.hashicorp.com/connect-inject=true
kubectl label namespace acceptance consul.hashicorp.com/connect-inject=true

# Add Consul namespace annotations
kubectl annotate namespace development consul.hashicorp.com/connect-service-namespace=development
kubectl annotate namespace testing consul.hashicorp.com/connect-service-namespace=testing
kubectl annotate namespace acceptance consul.hashicorp.com/connect-service-namespace=acceptance
```

#### Step 5.2: Create k8s-southwest1 Environment Namespaces
```bash
kubectl config use-context <gke-southwest1-context>

# Create environment namespaces
kubectl create namespace development
kubectl create namespace testing
kubectl create namespace production

# Label namespaces for Consul injection
kubectl label namespace development consul.hashicorp.com/connect-inject=true
kubectl label namespace testing consul.hashicorp.com/connect-inject=true
kubectl label namespace production consul.hashicorp.com/connect-inject=true

# Add Consul namespace annotations
kubectl annotate namespace development consul.hashicorp.com/connect-service-namespace=development
kubectl annotate namespace testing consul.hashicorp.com/connect-service-namespace=testing
kubectl annotate namespace production consul.hashicorp.com/connect-service-namespace=production
```

### Phase 6: Nomad API Gateway Deployment

#### Step 6.1: Deploy API Gateway to DC2
```bash
# Connect to DC2 cluster
export NOMAD_ADDR="http://<dc2-server-ip>:4646"
export NOMAD_TOKEN="<dc2-nomad-token>"

# Deploy API gateway for DC2
nomad job run clusters/dc2/jobs/api-gw.nomad.hcl

# Verify deployment
nomad job status my-api-gateway
nomad alloc status <allocation-id>
```

#### Step 6.2: Verify API Gateways
```bash
# Check DC1 API gateway
export NOMAD_ADDR="http://<dc1-server-ip>:4646"
export NOMAD_TOKEN="<dc1-nomad-token>"
nomad job status my-api-gateway

# Check DC2 API gateway
export NOMAD_ADDR="http://<dc2-server-ip>:4646"
export NOMAD_TOKEN="<dc2-nomad-token>"
nomad job status my-api-gateway
```

### Phase 7: Demo Application Deployment

#### Step 7.1: Deploy Demo-Fake App to k8s-west1 Environments

**Development Environment:**
```bash
kubectl config use-context <gke-west1-context>

# Deploy frontend to development
kubectl apply -n development -f consul/admin-partitions/manifests/demo-fake-app/k8s-west1/development/frontend.yaml

# Deploy backend to development
kubectl apply -n development -f consul/admin-partitions/manifests/demo-fake-app/k8s-west1/development/backend.yaml
```

**Testing Environment:**
```bash
# Deploy frontend to testing
kubectl apply -n testing -f consul/admin-partitions/manifests/demo-fake-app/k8s-west1/testing/frontend.yaml

# Deploy backend to testing
kubectl apply -n testing -f consul/admin-partitions/manifests/demo-fake-app/k8s-west1/testing/backend.yaml
```

**Acceptance Environment:**
```bash
# Deploy frontend to acceptance
kubectl apply -n acceptance -f consul/admin-partitions/manifests/demo-fake-app/k8s-west1/acceptance/frontend.yaml

# Deploy backend to acceptance
kubectl apply -n acceptance -f consul/admin-partitions/manifests/demo-fake-app/k8s-west1/acceptance/backend.yaml
```

#### Step 7.2: Deploy Demo-Fake App to k8s-southwest1 Environments

**Development Environment:**
```bash
kubectl config use-context <gke-southwest1-context>

# Deploy applications to development
kubectl apply -n development -f consul/admin-partitions/manifests/demo-fake-app/k8s-southwest1/development/
```

**Testing Environment:**
```bash
# Deploy applications to testing
kubectl apply -n testing -f consul/admin-partitions/manifests/demo-fake-app/k8s-southwest1/testing/
```

**Production Environment:**
```bash
# Deploy applications to production
kubectl apply -n production -f consul/admin-partitions/manifests/demo-fake-app/k8s-southwest1/production/
```

### Phase 8: Verification and Testing

#### Step 8.1: Verify Admin Partitions
```bash
# Check partitions exist
consul partition list

# Verify services in each partition
consul catalog services -partition k8s-west1
consul catalog services -partition k8s-southwest1
```

#### Step 8.2: Verify Services by Environment
```bash
# k8s-west1 services
consul catalog services -partition k8s-west1 -namespace development
consul catalog services -partition k8s-west1 -namespace testing
consul catalog services -partition k8s-west1 -namespace acceptance

# k8s-southwest1 services
consul catalog services -partition k8s-southwest1 -namespace development
consul catalog services -partition k8s-southwest1 -namespace testing
consul catalog services -partition k8s-southwest1 -namespace production
```

#### Step 8.3: Test Cross-Partition Communication
```bash
# Test communication from k8s-west1 to k8s-southwest1
kubectl config use-context <gke-west1-context>
kubectl exec -n development deployment/frontend -- \
  curl -s http://backend.development.k8s-southwest1.consul:9090/health

# Test communication from k8s-southwest1 to k8s-west1
kubectl config use-context <gke-southwest1-context>
kubectl exec -n development deployment/backend -- \
  curl -s http://frontend.development.k8s-west1.consul:9090/health
```

#### Step 8.4: Test API Gateway Access
```bash
# Get API gateway endpoints
export API_GW_DC1="http://<dc1-client-ip>:8081"
export API_GW_DC2="http://<dc2-client-ip>:8081"

# Test access through gateways
curl $API_GW_DC1/frontend/development
curl $API_GW_DC2/backend/development
```

## 📊 Environment Summary

| Partition | Cluster | Environments | Applications |
|-----------|---------|--------------|-------------|
| k8s-west1 | europe-west1 | development, testing, acceptance | frontend, backend |
| k8s-southwest1 | europe-southwest1 | development, testing, production | frontend, backend |

## 🔍 Troubleshooting Commands

```bash
# Check partition status
consul partition read k8s-west1
consul partition read k8s-southwest1

# Check ACL tokens
consul acl token read -id <token-id>

# Check service mesh connectivity
consul intention check frontend backend.development.k8s-southwest1

# Check Kubernetes pods
kubectl get pods -n consul --all-namespaces
kubectl logs -n consul -l app=consul,component=connect-injector

# Check Nomad API gateway
nomad alloc logs <api-gateway-alloc-id>
```

## 📁 Required Files Structure

```
consul/admin-partitions/
├── README.md                           # This file
├── policies/                           # ACL policy files
│   ├── k8s-west1-admin-policy.hcl
│   ├── k8s-west1-development-policy.hcl
│   ├── k8s-west1-testing-policy.hcl
│   ├── k8s-west1-acceptance-policy.hcl
│   ├── k8s-southwest1-admin-policy.hcl
│   ├── k8s-southwest1-development-policy.hcl
│   ├── k8s-southwest1-testing-policy.hcl
│   └── k8s-southwest1-production-policy.hcl
├── tokens/                             # Generated tokens (local only)
│   ├── k8s-west1-admin-token.txt
│   ├── k8s-west1-admin.token
│   ├── k8s-southwest1-admin-token.txt
│   └── k8s-southwest1-admin.token
└── manifests/                          # Kubernetes manifests (local only)
    └── demo-fake-app/
        ├── k8s-west1/
        │   ├── development/
        │   ├── testing/
        │   └── acceptance/
        └── k8s-southwest1/
            ├── development/
            ├── testing/
            └── production/
```

## ✅ Success Criteria

- [ ] Both admin partitions created and accessible
- [ ] All ACL policies and roles configured
- [ ] Both GKE clusters running Consul with correct partition names
- [ ] All environment namespaces created and labeled
- [ ] API gateways deployed to both DC1 and DC2
- [ ] Demo applications deployed to all environments
- [ ] Cross-partition service discovery working
- [ ] API gateway routing functional
- [ ] All services visible in Consul UI with correct partitions/namespaces