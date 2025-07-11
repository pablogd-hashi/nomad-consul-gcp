#!/bin/bash

# Setup script for Minikube Consul secrets
# Run this script to create the necessary secrets for Consul Helm chart

set -e

echo "Setting up Consul secrets for Minikube..."

# You'll need to replace these values with your actual secrets from DC1 cluster
# Get these from your DC1 terraform outputs

# 1. Enterprise License (get from terraform output)
echo "Creating Enterprise License secret..."
kubectl create secret generic consul-ent-license \
  --from-literal=key="YOUR_CONSUL_LICENSE_HERE" \
  --dry-run=client -o yaml | kubectl apply -f -

# 2. Bootstrap Token (get from terraform output)  
echo "Creating Bootstrap Token secret..."
kubectl create secret generic consul-bootstrap-token \
  --from-literal=token="YOUR_BOOTSTRAP_TOKEN_HERE" \
  --dry-run=client -o yaml | kubectl apply -f -

# 3. Partition Token (you may need to create this in Consul)
echo "Creating Partition Token secret..."
kubectl create secret generic consul-partitions-acl-token \
  --from-literal=token="YOUR_PARTITION_TOKEN_HERE" \
  --dry-run=client -o yaml | kubectl apply -f -

# 4. DNS Token (you may need to create this in Consul)
echo "Creating DNS Token secret..."
kubectl create secret generic consul-dns-token \
  --from-literal=token="YOUR_DNS_TOKEN_HERE" \
  --dry-run=client -o yaml | kubectl apply -f -

# 5. CA Certificate (get from DC1 server)
echo "Creating CA Certificate secret..."
# You'll need to copy the CA cert from your DC1 server: /etc/consul.d/tls/consul-agent-ca.pem
kubectl create secret generic consul-ca-cert \
  --from-file=tls.crt=/path/to/consul-agent-ca.pem \
  --dry-run=client -o yaml | kubectl apply -f -

# 6. CA Key (get from DC1 server)  
echo "Creating CA Key secret..."
# You'll need to copy the CA key from your DC1 server: /etc/consul.d/tls/consul-agent-ca-key.pem
kubectl create secret generic consul-ca-key \
  --from-file=tls.key=/path/to/consul-agent-ca-key.pem \
  --dry-run=client -o yaml | kubectl apply -f -

echo "All secrets created successfully!"
echo ""
echo "Next steps:"
echo "1. Update the paths in this script with your actual certificate files"
echo "2. Get the actual tokens from your DC1 cluster"
echo "3. Run: helm install consul hashicorp/consul -f minikube-consul-test.yaml"