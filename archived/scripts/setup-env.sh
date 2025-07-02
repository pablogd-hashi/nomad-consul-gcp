#!/bin/bash
# Script to set up environment variables for Consul and Nomad CLI access

set -e

echo "🔧 Setting up environment variables for HashiStack CLI access..."
echo "================================================================"

# Check if we're in the right directory
if [[ ! -f "terraform/main.tf" ]]; then
    echo "❌ Error: Please run this script from the repository root"
    exit 1
fi

cd terraform/

# Check if terraform has been applied
if ! terraform output consul_master_token >/dev/null 2>&1; then
    echo "❌ Error: Terraform output not available. Please run 'terraform apply' first."
    exit 1
fi

# Get server IP
SERVER_IP=$(terraform output -json consul_servers | jq -r '.["server-1"].public_ip')

if [[ "$SERVER_IP" == "null" || -z "$SERVER_IP" ]]; then
    echo "❌ Error: Could not get server IP from Terraform output"
    exit 1
fi

# Set environment variables
echo "📡 Setting environment variables..."

export CONSUL_HTTP_ADDR="http://$SERVER_IP:8500"
export CONSUL_HTTP_TOKEN=$(terraform output -raw consul_master_token)
export NOMAD_ADDR="http://$SERVER_IP:4646"
export NOMAD_TOKEN=$(terraform output -raw nomad_server_token)

echo "✅ Environment variables set:"
echo "   CONSUL_HTTP_ADDR=$CONSUL_HTTP_ADDR"
echo "   CONSUL_HTTP_TOKEN=***hidden***"
echo "   NOMAD_ADDR=$NOMAD_ADDR"
echo "   NOMAD_TOKEN=***hidden***"
echo ""

# Test connectivity
echo "🔍 Testing connectivity..."

# Test Consul
if curl -s -H "Authorization: Bearer $CONSUL_HTTP_TOKEN" "$CONSUL_HTTP_ADDR/v1/status/leader" | grep -q '"'; then
    echo "✅ Consul connectivity: OK"
else
    echo "❌ Consul connectivity: FAILED"
fi

# Test Nomad
if curl -s -H "X-Nomad-Token: $NOMAD_TOKEN" "$NOMAD_ADDR/v1/status/leader" | grep -q '"'; then
    echo "✅ Nomad connectivity: OK"
else
    echo "❌ Nomad connectivity: FAILED"
fi

echo ""
echo "================================================================"
echo "🚀 Ready to use CLI commands!"
echo "================================================================"
echo ""
echo "Run these commands to set variables in your current shell:"
echo ""
echo "export CONSUL_HTTP_ADDR=\"$CONSUL_HTTP_ADDR\""
echo "export CONSUL_HTTP_TOKEN=\"$CONSUL_HTTP_TOKEN\""
echo "export NOMAD_ADDR=\"$NOMAD_ADDR\""
echo "export NOMAD_TOKEN=\"$NOMAD_TOKEN\""
echo ""
echo "Or source this script to set them automatically:"
echo "source ./scripts/setup-env.sh"
echo ""
echo "================================================================"
echo "📋 Available Commands:"
echo "================================================================"
echo ""
echo "# Consul operations"
echo "consul members"
echo "consul catalog services"
echo "consul kv get -recurse"
echo ""
echo "# Nomad operations"
echo "nomad server members"
echo "nomad node status"
echo "nomad job status"
echo "nomad setup consul -y    # Set up Consul integration"
echo ""
echo "# Access UIs"
echo "echo \"Consul UI: $CONSUL_HTTP_ADDR\""
echo "echo \"Nomad UI:  $NOMAD_ADDR\""
echo "echo \"Use token: $NOMAD_TOKEN\" # For Nomad UI"
echo ""