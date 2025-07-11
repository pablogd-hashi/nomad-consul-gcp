# Consul Admin Partitions - Complete Guide

This guide covers creating and managing Consul Enterprise admin partitions for cross-platform service mesh integration.

## Overview

Admin partitions provide:
- ✅ **Multi-tenancy isolation** - Separate namespaces for different platforms
- ✅ **Cross-platform service mesh** - Kubernetes ↔ Nomad communication
- ✅ **Security boundaries** - ACL isolation between partitions
- ✅ **Unified service discovery** - Services discoverable across platforms

## Architecture

```
┌──────────────────┐    ┌─────────────────┐
│ Default Partition│    │ k8s-test        │
│ (Nomad workloads)│◄──►│ (GKE workloads) │
│ - frontend       │    │ - frontend      │
│ - backend        │    │ - backend       │
│ - api-gateway    │    │                 │
└──────────────────┘    └─────────────────┘
```

## Prerequisites

1. **Consul Enterprise** with admin partitions enabled
2. **Access to Consul servers** with bootstrap token
3. **consul CLI** configured

## Environment Setup

Set your Consul environment (use actual server IPs from europe-west1):

```bash
# Set Consul environment
export CONSUL_HTTP_ADDR="http://34.175.140.62:8500"
export CONSUL_HTTP_TOKEN="ConsulR0cks"  # Your bootstrap token

# Verify connection
consul members
```

## Creating Admin Partitions

### Step 1: Create the k8s-test Partition

```bash
# Create the admin partition
echo 'Name = "k8s-test"
Description = "Admin partition for Kubernetes testing"' | consul partition write -

# Verify creation
consul partition list
```

### Step 2: Create Partition Policy

```bash
# Create comprehensive policy for the partition
consul acl policy create \
  -partition "k8s-test" \
  -name "k8s-test-partition-policy" \
  -description "Full access policy for k8s-test partition" \
  -rules='
# Namespace permissions
namespace_prefix "" {
  policy = "write"
  intentions = "write"
}

# Service permissions
service_prefix "" {
  policy = "write"
  intentions = "write"
}

# Node permissions
node_prefix "" {
  policy = "write"
}

# Key-value permissions
key_prefix "" {
  policy = "write"
}

# Session permissions
session_prefix "" {
  policy = "write"
}

# Mesh and peering permissions
mesh = "write"
peering = "write"

# Agent permissions
agent_prefix "" {
  policy = "write"
}

# Event permissions
event_prefix "" {
  policy = "write"
}

# Query permissions
query_prefix "" {
  policy = "write"
}'
```

### Step 3: Create Partition Token

```bash
# Create partition token with the policy
PARTITION_TOKEN=$(consul acl token create \
  -description "Token for k8s-test partition" \
  -partition "k8s-test" \
  -policy-name "k8s-test-partition-policy" \
  -format json | jq -r '.SecretID')

echo "Partition token created: $PARTITION_TOKEN"
echo "Save this token for Kubernetes secrets!"
```

## Setting Up Kubernetes Auth Method

If you need ACL authentication within the partition:

```bash
# Get GKE cluster details
GKE_ENDPOINT=$(kubectl cluster-info | grep 'control plane' | grep -oE 'https://[^[:space:]]*')
echo "GKE API Endpoint: $GKE_ENDPOINT"

# Get Kubernetes CA certificate
kubectl config view --raw --minify --flatten -o jsonpath='{.clusters[].cluster.certificate-authority-data}' | base64 --decode > /tmp/k8s-ca.pem

# Create service account for authentication
kubectl create serviceaccount consul-auth -n consul --dry-run=client -o yaml | kubectl apply -f -

# Get JWT token
JWT_TOKEN=$(kubectl create token consul-auth -n consul --duration=8760h)

# Create Kubernetes auth method
consul acl auth-method create \
  -type=kubernetes \
  -name=gke-k8s-test \
  -partition=k8s-test \
  -kubernetes-host="$GKE_ENDPOINT" \
  -kubernetes-ca-cert="$(cat /tmp/k8s-ca.pem)" \
  -kubernetes-service-account-jwt="$JWT_TOKEN"

# Create binding rule for service authentication
consul acl binding-rule create \
  -method=gke-k8s-test \
  -partition=k8s-test \
  -bind-type=service \
  -bind-name='${serviceaccount.name}' \
  -selector='serviceaccount.namespace==default'

# Cleanup
rm -f /tmp/k8s-ca.pem
```

## Verifying Partitions

### Check Partition Status

```bash
# List all partitions
consul partition list

# Read specific partition
consul partition read k8s-test

# List services in partition
consul catalog services -partition k8s-test

# List nodes in partition
consul catalog nodes -partition k8s-test
```

### Check ACL Configuration

```bash
# List policies in partition
consul acl policy list -partition k8s-test

# List tokens in partition
consul acl token list -partition k8s-test

# Verify auth method
consul acl auth-method read -name gke-k8s-test -partition k8s-test
```

## Cross-Partition Service Discovery

Services in different partitions can discover each other using:

### From Kubernetes to Nomad Services

```yaml
annotations:
  consul.hashicorp.com/connect-service-upstreams: "backend.default.default:8080"
```

### From Nomad to Kubernetes Services

```hcl
upstream {
  destination_name = "frontend"
  destination_partition = "k8s-test"
  local_bind_port = 8080
}
```

## Partition Management Commands

### Update Partition

```bash
# Update partition description
echo 'Name = "k8s-test"
Description = "Updated description for k8s partition"' | consul partition write -
```

### Delete Partition

⚠️ **Warning**: This will remove all services and configuration in the partition!

```bash
# Delete partition (removes all services)
consul partition delete k8s-test
```

## Troubleshooting

### Common Issues

```bash
# Check if services are registered in correct partition
consul catalog services -partition k8s-test

# Verify token permissions
consul acl token read -id $PARTITION_TOKEN

# Check auth method configuration
consul acl auth-method read -name gke-k8s-test -partition k8s-test

# Test cross-partition connectivity
consul intention check -source frontend -destination backend.default.default
```

### Service Registration Issues

```bash
# Check if Consul agents can reach servers
kubectl exec -n consul <consul-pod> -- consul members

# Verify partition token is correct
kubectl get secret consul-partitions-acl-token -n consul -o jsonpath='{.data.token}' | base64 -d

# Check service mesh injection
kubectl describe pod <pod-name> -n <namespace>
```

## Best Practices

1. **Use descriptive partition names** - `k8s-prod`, `nomad-staging`, etc.
2. **Limit partition scope** - Don't create too many partitions
3. **Plan ACL policies carefully** - Start with minimal permissions
4. **Monitor cross-partition traffic** - Use Consul metrics and logs
5. **Document partition purposes** - Keep clear documentation

## Integration with GKE

When using with the GKE setup in this repository:

1. **Partition**: `k8s-test`
2. **Token**: Created with this guide
3. **Kubernetes secret**: `consul-partitions-acl-token`
4. **Helm values**: References the partition in `gke-consul-values.yaml`

See `clusters/gke-europe-west1/manifests/README.md` for complete GKE integration guide.

## Success Criteria

✅ **Partition created**: `consul partition list` shows k8s-test  
✅ **Token working**: Services can authenticate to partition  
✅ **Services registered**: Kubernetes services appear in Consul  
✅ **Cross-partition discovery**: Services can find each other  
✅ **Service mesh active**: Envoy sidecars injected and working