#!/bin/bash
# Consul ACL Bootstrap Script

set -e

echo "Starting Consul ACL Bootstrap process..."

# Wait for Consul to be ready
wait_for_consul() {
    local max_attempts=30
    local attempt=0
    
    while [ $attempt -lt $max_attempts ]; do
        if curl -s http://localhost:8500/v1/status/leader | grep -q '"'; then
            echo "Consul is ready"
            return 0
        fi
        echo "Waiting for Consul to be ready... (attempt $((attempt + 1))/$max_attempts)"
        sleep 10
        attempt=$((attempt + 1))
    done
    
    echo "Consul failed to become ready"
    return 1
}

# Bootstrap ACL system (only run on first server)
bootstrap_acls() {
    echo "Bootstrapping ACL system..."
    
    # Bootstrap and capture the management token
    BOOTSTRAP_OUTPUT=$(consul acl bootstrap 2>/dev/null || echo "already_bootstrapped")
    
    if [[ "$BOOTSTRAP_OUTPUT" == "already_bootstrapped" ]]; then
        echo "ACL system already bootstrapped"
        return 0
    fi
    
    # Extract the SecretID (management token)
    MANAGEMENT_TOKEN=$(echo "$BOOTSTRAP_OUTPUT" | grep "SecretID:" | awk '{print $2}')
    
    if [[ -z "$MANAGEMENT_TOKEN" ]]; then
        echo "Failed to extract management token"
        return 1
    fi
    
    echo "ACL system bootstrapped successfully"
    echo "Management Token: $MANAGEMENT_TOKEN"
    
    # Store the management token securely
    echo "$MANAGEMENT_TOKEN" > /opt/consul/management-token
    chmod 600 /opt/consul/management-token
    chown consul:consul /opt/consul/management-token
    
    # Export for use in subsequent commands
    export CONSUL_HTTP_TOKEN="$MANAGEMENT_TOKEN"
    
    return 0
}

# Create ACL policies
create_policies() {
    local token=$1
    export CONSUL_HTTP_TOKEN="$token"
    
    echo "Creating ACL policies..."
    
    # Nomad Server Policy
    consul acl policy create \
        -name "nomad-server" \
        -description "Policy for Nomad servers" \
        -rules @/tmp/nomad-server-policy.hcl 2>/dev/null || echo "Policy nomad-server already exists"
    
    # Nomad Client Policy  
    consul acl policy create \
        -name "nomad-client" \
        -description "Policy for Nomad clients" \
        -rules @/tmp/nomad-client-policy.hcl 2>/dev/null || echo "Policy nomad-client already exists"
    
    # Application Policy
    consul acl policy create \
        -name "application" \
        -description "Policy for applications" \
        -rules @/tmp/application-policy.hcl 2>/dev/null || echo "Policy application already exists"
        
    # Anonymous Policy
    consul acl policy create \
        -name "anonymous" \
        -description "Policy for anonymous access" \
        -rules @/tmp/anonymous-policy.hcl 2>/dev/null || echo "Policy anonymous already exists"
}

# Create ACL tokens
create_tokens() {
    local management_token=$1
    export CONSUL_HTTP_TOKEN="$management_token"
    
    echo "Creating ACL tokens..."
    
    # Nomad Server Token
    NOMAD_SERVER_TOKEN=$(consul acl token create \
        -description "Token for Nomad servers" \
        -policy-name "nomad-server" \
        -format=json 2>/dev/null | jq -r '.SecretID' || echo "")
    
    if [[ -n "$NOMAD_SERVER_TOKEN" && "$NOMAD_SERVER_TOKEN" != "null" ]]; then
        echo "$NOMAD_SERVER_TOKEN" > /opt/consul/nomad-server-token
        chmod 600 /opt/consul/nomad-server-token
        chown consul:consul /opt/consul/nomad-server-token
        echo "Nomad server token created"
    fi
    
    # Nomad Client Token
    NOMAD_CLIENT_TOKEN=$(consul acl token create \
        -description "Token for Nomad clients" \
        -policy-name "nomad-client" \
        -format=json 2>/dev/null | jq -r '.SecretID' || echo "")
    
    if [[ -n "$NOMAD_CLIENT_TOKEN" && "$NOMAD_CLIENT_TOKEN" != "null" ]]; then
        echo "$NOMAD_CLIENT_TOKEN" > /opt/consul/nomad-client-token
        chmod 600 /opt/consul/nomad-client-token
        chown consul:consul /opt/consul/nomad-client-token
        echo "Nomad client token created"
    fi
    
    # Application Token
    APP_TOKEN=$(consul acl token create \
        -description "Token for applications" \
        -policy-name "application" \
        -format=json 2>/dev/null | jq -r '.SecretID' || echo "")
    
    if [[ -n "$APP_TOKEN" && "$APP_TOKEN" != "null" ]]; then
        echo "$APP_TOKEN" > /opt/consul/application-token
        chmod 600 /opt/consul/application-token
        chown consul:consul /opt/consul/application-token
        echo "Application token created"
    fi
}

# Update anonymous token policy
update_anonymous_policy() {
    local management_token=$1
    export CONSUL_HTTP_TOKEN="$management_token"
    
    echo "Updating anonymous token policy..."
    
    # Get the anonymous token ID
    ANONYMOUS_TOKEN_ID=$(consul acl token list -format=json | jq -r '.[] | select(.Description == "Anonymous Token") | .AccessorID')
    
    if [[ -n "$ANONYMOUS_TOKEN_ID" && "$ANONYMOUS_TOKEN_ID" != "null" ]]; then
        consul acl token update \
            -id "$ANONYMOUS_TOKEN_ID" \
            -policy-name "anonymous" \
            -description "Anonymous Token with limited access" 2>/dev/null || echo "Failed to update anonymous token"
    fi
}

# Main execution
main() {
    # Wait for Consul to be ready
    wait_for_consul
    
    # Check if we're the first server (based on hostname or environment variable)
    if [[ "$HOSTNAME" == *"server-1"* ]] || [[ "$CONSUL_BOOTSTRAP" == "true" ]]; then
        echo "This is the bootstrap server, initializing ACL system..."
        
        # Bootstrap ACLs
        bootstrap_acls
        
        # Get the management token
        if [[ -f /opt/consul/management-token ]]; then
            MANAGEMENT_TOKEN=$(cat /opt/consul/management-token)
        else
            echo "Management token not found, ACL bootstrap may have failed"
            exit 1
        fi
        
        # Create policies and tokens
        create_policies "$MANAGEMENT_TOKEN"
        create_tokens "$MANAGEMENT_TOKEN"
        update_anonymous_policy "$MANAGEMENT_TOKEN"
        
        echo "ACL bootstrap completed successfully"
        
        # Output token information for Terraform to capture
        echo "=== TOKEN OUTPUT ==="
        echo "CONSUL_MANAGEMENT_TOKEN=$MANAGEMENT_TOKEN"
        echo "NOMAD_SERVER_TOKEN=$(cat /opt/consul/nomad-server-token 2>/dev/null || echo '')"
        echo "NOMAD_CLIENT_TOKEN=$(cat /opt/consul/nomad-client-token 2>/dev/null || echo '')"
        echo "APPLICATION_TOKEN=$(cat /opt/consul/application-token 2>/dev/null || echo '')"
        echo "=== END TOKEN OUTPUT ==="
        
    else
        echo "This is not the bootstrap server, skipping ACL initialization"
    fi
}

# Run the main function
main "$@"