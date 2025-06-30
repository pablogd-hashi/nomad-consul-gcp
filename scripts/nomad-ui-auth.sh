#!/bin/bash
# Script to handle Nomad UI authentication
# The 'nomad ui -authenticate' command doesn't work with bootstrap management tokens
# This script provides alternatives for UI access

set -e

echo "🔐 Nomad UI Authentication Helper"
echo "=================================="

# Check if we're in the right directory
if [[ ! -f "terraform/main.tf" ]]; then
    echo "❌ Error: Please run this script from the repository root"
    exit 1
fi

cd terraform/

# Check if terraform has been applied
if ! terraform output nomad_server_token >/dev/null 2>&1; then
    echo "❌ Error: Terraform output not available. Please run 'terraform apply' first."
    exit 1
fi

# Get server IP and token
SERVER_IP=$(terraform output -json consul_servers | jq -r '.["server-1"].public_ip')
NOMAD_TOKEN=$(terraform output -raw nomad_server_token)
NOMAD_URL="http://$SERVER_IP:4646"

if [[ "$SERVER_IP" == "null" || -z "$SERVER_IP" ]]; then
    echo "❌ Error: Could not get server IP from Terraform output"
    exit 1
fi

echo "📡 Nomad Server: $NOMAD_URL"
echo ""

# Test if the management token works
echo "🔍 Testing Nomad connectivity..."
if curl -s -H "X-Nomad-Token: $NOMAD_TOKEN" "$NOMAD_URL/v1/status/leader" | grep -q '"'; then
    echo "✅ Nomad connectivity: OK"
else
    echo "❌ Nomad connectivity: FAILED"
    exit 1
fi

echo ""
echo "💡 Nomad UI Authentication Options:"
echo "===================================="
echo ""

echo "🎯 Option 1: Use Management Token Directly (Recommended)"
echo "---------------------------------------------------------"
echo "1. Open Nomad UI: $NOMAD_URL"
echo "2. Click 'ACL Tokens' in top-right corner"
echo "3. Paste this token:"
echo ""
echo "   $NOMAD_TOKEN"
echo ""

echo "🎯 Option 2: Create a UI-Specific Token (Advanced)"
echo "---------------------------------------------------"
echo "You can create a limited token for UI access:"
echo ""

# Check if we can create ACL policies
echo "# First, set environment variables:"
echo "export NOMAD_ADDR=\"$NOMAD_URL\""
echo "export NOMAD_TOKEN=\"$NOMAD_TOKEN\""
echo ""
echo "# Then create a UI policy:"
cat << 'EOF'
nomad acl policy apply ui-access - << 'POLICY'
namespace "*" {
  policy = "read"
}

agent {
  policy = "read"
}

node {
  policy = "read"
}

plugin {
  policy = "read"
}

quota {
  policy = "read"
}
POLICY
EOF

echo ""
echo "# Create a token with this policy:"
echo "nomad acl token create -name=\"ui-token\" -policy=\"ui-access\""
echo ""

echo "🎯 Option 3: Enable Anonymous Access (Less Secure)"
echo "---------------------------------------------------"
echo "For development environments, you can enable anonymous access:"
echo ""
echo "# Create anonymous policy:"
cat << 'EOF'
nomad acl policy apply anonymous - << 'POLICY'
namespace "*" {
  policy = "read"
}

agent {
  policy = "read"
}

node {
  policy = "read"
}
POLICY
EOF

echo ""
echo "# Update anonymous token:"
echo "nomad acl token update -name=\"Anonymous Token\" -policy=\"anonymous\" \$(nomad acl token list | grep Anonymous | awk '{print \$1}')"
echo ""

echo "🔧 Why 'nomad ui -authenticate' Doesn't Work:"
echo "=============================================="
echo "The 'nomad ui -authenticate' command requires:"
echo "1. A proper ACL setup with management capabilities"
echo "2. The ability to create one-time tokens"
echo "3. Specific ACL permissions that aren't available with bootstrap tokens"
echo ""
echo "The current setup uses a pre-generated bootstrap management token,"
echo "which has full access but doesn't support the UI authentication flow."
echo ""

echo "✅ Quick Access:"
echo "================"
echo "🌐 Nomad UI: $NOMAD_URL"
echo "🔑 Token: $NOMAD_TOKEN"
echo ""
echo "Just paste the token into the UI for immediate access!"