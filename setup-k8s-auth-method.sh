#!/bin/bash

# Setup Kubernetes Auth Method for k8s-east Partition
# This script does everything: gets minikube IP, CA cert, and sets up auth method

set -e

echo "=== Setting up Kubernetes Auth Method for k8s-east partition ==="

# Set Consul server details for DC1
export CONSUL_HTTP_ADDR="http://34.175.140.62:8500"
export CONSUL_HTTP_TOKEN="ConsulR0cks"

echo "Using Consul server: $CONSUL_HTTP_ADDR"

# Get minikube details
echo "Getting minikube cluster details..."

# Get minikube IP
echo "Getting minikube IP..."
MINIKUBE_IP=$(minikube ip 2>/dev/null)
if [ -z "$MINIKUBE_IP" ]; then
    echo "ERROR: Could not get minikube IP. Is minikube running?"
    echo "Run: minikube start"
    exit 1
fi

MINIKUBE_PORT=8443

echo "Minikube IP: $MINIKUBE_IP"
echo "Minikube Port: $MINIKUBE_PORT"

# Get Kubernetes CA certificate
echo "Getting Kubernetes CA certificate..."
kubectl config view --raw --minify --flatten -o jsonpath='{.clusters[].cluster.certificate-authority-data}' | base64 --decode > /tmp/k8s-ca.pem

if [ ! -f "/tmp/k8s-ca.pem" ]; then
    echo "ERROR: Failed to get Kubernetes CA certificate"
    exit 1
fi

echo "CA certificate saved to /tmp/k8s-ca.pem"

# Check if auth method already exists
echo "Checking if auth method already exists..."
if consul acl auth-method read -name minikube-k8s-east -partition k8s-east >/dev/null 2>&1; then
    echo "Auth method already exists, deleting it first..."
    consul acl auth-method delete -name minikube-k8s-east -partition k8s-east
fi

# Get a service account JWT for authentication
echo "Creating service account and getting JWT..."
kubectl create serviceaccount consul-auth -n default --dry-run=client -o yaml | kubectl apply -f -

# Get the JWT token
JWT_TOKEN=$(kubectl create token consul-auth -n default --duration=8760h)

# Create the Kubernetes auth method
echo "Creating Kubernetes auth method for k8s-east partition..."
consul acl auth-method create \
    -type=kubernetes \
    -name=minikube-k8s-east \
    -partition=k8s-east \
    -kubernetes-host="https://${MINIKUBE_IP}:${MINIKUBE_PORT}" \
    -kubernetes-ca-cert="$(cat /tmp/k8s-ca.pem)" \
    -kubernetes-service-account-jwt="$JWT_TOKEN"

echo "Auth method created successfully!"

# Create binding rule
echo "Creating binding rule..."
if consul acl binding-rule list -method minikube-k8s-east -partition k8s-east | grep -q "consul-"; then
    echo "Binding rule already exists, skipping..."
else
    consul acl binding-rule create \
        -method=minikube-k8s-east \
        -partition=k8s-east \
        -bind-type=service \
        -bind-name='consul-${serviceaccount.name}' \
        -selector='serviceaccount.namespace==consul'
    echo "Binding rule created successfully!"
fi

# Verify the setup
echo ""
echo "=== Verification ==="
echo "Auth method details:"
consul acl auth-method read -name minikube-k8s-east -partition k8s-east

echo ""
echo "Binding rules:"
consul acl binding-rule list -method minikube-k8s-east -partition k8s-east

echo ""
echo "=== Setup Complete ==="
echo "You can now deploy Consul to minikube using:"
echo "helm install consul hashicorp/consul -f minikube-consul-test.yaml -n consul"

# Cleanup
rm -f /tmp/k8s-ca.pem