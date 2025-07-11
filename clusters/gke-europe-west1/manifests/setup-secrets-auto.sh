#!/bin/bash

# GKE Consul Secrets Setup Script (Automated)
# This script creates all necessary secrets for Consul integration with DC1 HashiStack

set -e

echo "Setting up Consul secrets for GKE integration..."

# Get the current DC1 directory
DC1_DIR="../../dc1/terraform"

# Check if we can access DC1 terraform directory
if [ ! -d "$DC1_DIR" ]; then
    echo "Error: Cannot find DC1 terraform directory at $DC1_DIR"
    exit 1
fi

# Create consul namespace
echo "Creating consul namespace..."
kubectl create namespace consul --dry-run=client -o yaml | kubectl apply -f -

# Get tokens from DC1 terraform output
echo "Getting tokens from DC1 terraform output..."
cd "$DC1_DIR"

# Try to get the consul license from terraform output
CONSUL_LICENSE=""
if command -v terraform >/dev/null 2>&1; then
    # Try to get license from terraform output (if available)
    CONSUL_LICENSE=$(terraform output -raw consul_license 2>/dev/null || echo "")
fi

# If license not found, check environment variable
if [ -z "$CONSUL_LICENSE" ]; then
    if [ -n "$CONSUL_ENT_LICENSE" ]; then
        CONSUL_LICENSE="$CONSUL_ENT_LICENSE"
    else
        echo "Error: Consul Enterprise license not found."
        echo "Please set CONSUL_ENT_LICENSE environment variable or run the interactive script."
        exit 1
    fi
fi

# Get bootstrap token
BOOTSTRAP_TOKEN=$(terraform output -raw auth_tokens 2>/dev/null | jq -r '.consul_token' 2>/dev/null || echo "")
if [ "$BOOTSTRAP_TOKEN" == "null" ] || [ -z "$BOOTSTRAP_TOKEN" ]; then
    echo "Error: Bootstrap token not found in terraform output."
    echo "Please run terraform apply first or set token manually."
    exit 1
fi

# Get k8s-west partition token
K8S_WEST_TOKEN=""
if [ -f "gke/k8s-west-token.txt" ]; then
    K8S_WEST_TOKEN=$(grep "SecretID:" gke/k8s-west-token.txt | awk '{print $2}')
    echo "Found k8s-west partition token: ${K8S_WEST_TOKEN:0:8}..."
else
    echo "Warning: k8s-west-token.txt not found, using bootstrap token"
    K8S_WEST_TOKEN="$BOOTSTRAP_TOKEN"
fi

cd - > /dev/null

# 1. Consul Enterprise License Secret
echo "Creating Consul Enterprise license secret..."
kubectl create secret generic consul-ent-license \
  --namespace=consul \
  --from-literal=key="$CONSUL_LICENSE" \
  --dry-run=client -o yaml | kubectl apply -f -

# 2. Consul CA Certificate
echo "Creating Consul CA certificate secret..."
kubectl create secret generic consul-ca-cert \
  --namespace=consul \
  --from-file=tls.crt="$DC1_DIR/consul-agent-ca.pem" \
  --dry-run=client -o yaml | kubectl apply -f -

# 3. Consul CA Key
echo "Creating Consul CA key secret..."
kubectl create secret generic consul-ca-key \
  --namespace=consul \
  --from-file=tls.key="$DC1_DIR/consul-agent-ca-key.pem" \
  --dry-run=client -o yaml | kubectl apply -f -

# 4. Bootstrap Token
echo "Creating bootstrap token secret..."
kubectl create secret generic consul-bootstrap-token \
  --namespace=consul \
  --from-literal=token="$BOOTSTRAP_TOKEN" \
  --dry-run=client -o yaml | kubectl apply -f -

# 5. Partitions ACL Token (use k8s-west partition token)
echo "Creating partitions ACL token secret..."
kubectl create secret generic consul-partitions-acl-token \
  --namespace=consul \
  --from-literal=token="$K8S_WEST_TOKEN" \
  --dry-run=client -o yaml | kubectl apply -f -

# 6. DNS Token (same as bootstrap for now)
echo "Creating DNS token secret..."
kubectl create secret generic consul-dns-token \
  --namespace=consul \
  --from-literal=token="$BOOTSTRAP_TOKEN" \
  --dry-run=client -o yaml | kubectl apply -f -

echo "All secrets created successfully!"
echo ""
echo "Secrets created:"
kubectl get secrets -n consul
echo ""
echo "You can now deploy Consul with:"
echo "helm repo add hashicorp https://helm.releases.hashicorp.com"
echo "helm repo update"
echo "helm install consul hashicorp/consul --namespace consul --values gke-consul-values.yaml"