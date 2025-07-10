#!/bin/bash
set -e

# Check if CONSUL_LICENSE is set
if [ -z "$CONSUL_LICENSE" ]; then
    echo "❌ CONSUL_LICENSE environment variable is not set"
    echo "Please set your Consul Enterprise license:"
    echo "export CONSUL_LICENSE=\"02MV4UU43BK5HGYYTOJZWFQMTMN...\""
    exit 1
fi

echo "✅ CONSUL_LICENSE is set (${#CONSUL_LICENSE} characters)"

# Set default project ID if not provided
PROJECT_ID=${PROJECT_ID:-hc-1031dcc8d7c24bfdbb4c08979b0}
echo "✅ Using PROJECT_ID: $PROJECT_ID"

# Deploy server-east
echo "📍 Deploying Consul servers in us-east1..."
cd terraform/server-east
terraform init
terraform apply -auto-approve \
    -var="consul_license=$CONSUL_LICENSE" \
    -var="project_id=$PROJECT_ID"
cd ../..

echo "✅ Server-east deployment complete!"