#!/bin/bash
# Quick script to get all tokens after Terraform deployment

echo "🔐 Getting all authentication tokens..."
echo "================================================"

# Get all tokens from Terraform output
echo "📋 Copying tokens to clipboard and displaying..."
echo ""

# Display individual tokens
echo "🔑 Consul Master Token:"
terraform output -raw consul_master_token
echo ""
echo ""

echo "🔑 Nomad Server Token:"  
terraform output -raw nomad_server_token
echo ""
echo ""

echo "🔑 Nomad Client Token:"
terraform output -raw nomad_client_token
echo ""
echo ""

echo "🔑 Application Token:"
terraform output -raw application_token
echo ""
echo ""

echo "🔒 Consul Encryption Key:"
terraform output -raw consul_encrypt_key
echo ""
echo ""

echo "🔒 Nomad Encryption Key:"
terraform output -raw nomad_encrypt_key
echo ""
echo ""

echo "================================================"
echo "🚀 Quick Setup Commands:"
echo "================================================"

# Get first server IP
SERVER_IP=$(terraform output -json consul_servers | jq -r '.["server-1"].public_ip')

echo "# Set environment variables for Consul CLI:"
echo "export CONSUL_HTTP_ADDR=http://$SERVER_IP:8500"
echo "export CONSUL_HTTP_TOKEN=$(terraform output -raw consul_master_token)"
echo ""

echo "# Set environment variables for Nomad CLI:"
echo "export NOMAD_ADDR=http://$SERVER_IP:4646"
echo "export NOMAD_TOKEN=$(terraform output -raw nomad_server_token)"
echo ""

echo "# Quick access URLs:"
echo "Consul UI: http://$SERVER_IP:8500"
echo "Nomad UI:  http://$SERVER_IP:4646"
echo ""

echo "# SSH to first server:"
echo "ssh ubuntu@$SERVER_IP"
echo ""

echo "================================================"
echo "🎯 All tokens available in JSON format:"
echo "================================================"
terraform output -json all_tokens | jq '.'