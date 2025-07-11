#!/bin/bash

# Quick Minikube Consul Test Setup
# This script sets up a simple test with your actual DC1 tokens

set -e

echo "=== Quick Minikube Consul Setup ==="

# Create namespace
kubectl create namespace consul --dry-run=client -o yaml | kubectl apply -f -
kubectl config set-context --current --namespace=consul

# Create secrets with actual DC1 values
echo "Creating secrets..."

# Bootstrap token (using your actual consul token)
kubectl create secret generic consul-bootstrap-token \
  --from-literal=token="ConsulR0cks" \
  --dry-run=client -o yaml | kubectl apply -f -

# Partition token (using same token for testing)
kubectl create secret generic consul-partitions-acl-token \
  --from-literal=token="ConsulR0cks" \
  --dry-run=client -o yaml | kubectl apply -f -

# DNS token (using same token for testing)
kubectl create secret generic consul-dns-token \
  --from-literal=token="ConsulR0cks" \
  --dry-run=client -o yaml | kubectl apply -f -

# Enterprise license (you'll need to add this manually)
echo "Creating enterprise license secret..."
echo "NOTE: You need to add your actual Consul Enterprise license"
kubectl create secret generic consul-ent-license \
  --from-literal=key="YOUR_CONSUL_LICENSE_HERE" \
  --dry-run=client -o yaml | kubectl apply -f -

# CA Certificate (you'll need to copy from DC1)
echo "NOTE: You need to copy CA certificates from DC1:"
echo "1. Copy /etc/consul.d/tls/consul-agent-ca.pem from DC1 server"
echo "2. Copy /etc/consul.d/tls/consul-agent-ca-key.pem from DC1 server"
echo "3. Run these commands:"
echo "   kubectl create secret generic consul-ca-cert --from-file=tls.crt=consul-agent-ca.pem"
echo "   kubectl create secret generic consul-ca-key --from-file=tls.key=consul-agent-ca-key.pem"

echo ""
echo "After setting up certificates, run:"
echo "helm repo add hashicorp https://helm.releases.hashicorp.com"
echo "helm install consul hashicorp/consul -f minikube-consul-test.yaml"