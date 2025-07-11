#!/bin/bash

# GKE Consul Secrets Setup Script
# This script creates all necessary secrets for Consul integration with DC1 HashiStack

set -e

echo "Setting up Consul secrets for GKE integration..."

# Get the current DC1 directory
DC1_DIR="../../../clusters/dc1/terraform"

# Check if we can access DC1 terraform directory
if [ ! -d "$DC1_DIR" ]; then
    echo "Error: Cannot find DC1 terraform directory at $DC1_DIR"
    exit 1
fi

# Create consul namespace
echo "Creating consul namespace..."
kubectl create namespace consul --dry-run=client -o yaml | kubectl apply -f -

# 1. Consul Enterprise License Secret
echo "Creating Consul Enterprise license secret..."
echo "Please provide your Consul Enterprise license:"
read -s CONSUL_LICENSE
kubectl create secret generic consul-ent-license \
  --namespace=consul \
  --from-literal=key="$CONSUL_LICENSE"

# 2. Consul CA Certificate
echo "Creating Consul CA certificate secret..."
kubectl create secret generic consul-ca-cert \
  --namespace=consul \
  --from-file=tls.crt="$DC1_DIR/consul-agent-ca.pem"

# 3. Consul CA Key
echo "Creating Consul CA key secret..."
kubectl create secret generic consul-ca-key \
  --namespace=consul \
  --from-file=tls.key="$DC1_DIR/consul-agent-ca-key.pem"

# 4. Bootstrap Token (get from DC1 terraform output)
echo "Getting bootstrap token from DC1..."
cd "$DC1_DIR"
BOOTSTRAP_TOKEN=$(terraform output -raw auth_tokens | jq -r '.consul_token')
if [ "$BOOTSTRAP_TOKEN" == "null" ] || [ -z "$BOOTSTRAP_TOKEN" ]; then
    echo "Warning: Could not get bootstrap token from terraform. Using default."
    BOOTSTRAP_TOKEN="Consu43v3r"
fi
cd - > /dev/null

kubectl create secret generic consul-bootstrap-token \
  --namespace=consul \
  --from-literal=token="$BOOTSTRAP_TOKEN"

# 5. Partitions ACL Token (same as bootstrap for now)
echo "Creating partitions ACL token secret..."
kubectl create secret generic consul-partitions-acl-token \
  --namespace=consul \
  --from-literal=token="$BOOTSTRAP_TOKEN"

# 6. DNS Token (same as bootstrap for now)
echo "Creating DNS token secret..."
kubectl create secret generic consul-dns-token \
  --namespace=consul \
  --from-literal=token="$BOOTSTRAP_TOKEN"

echo "All secrets created successfully!"
echo ""
echo "You can now deploy Consul with:"
echo "helm repo add hashicorp https://helm.releases.hashicorp.com"
echo "helm repo update"
echo "helm install consul hashicorp/consul --namespace consul --values gke-consul-values.yaml"
echo ""
echo "To verify secrets:"
echo "kubectl get secrets -n consul"