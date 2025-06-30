#!/bin/bash
# ACL Policy Setup for Nomad-Consul Integration

set -e

echo "Setting up ACL policies for Nomad-Consul integration..."

# Nomad Server Policy for Consul
cat > /tmp/nomad-server-policy.hcl << 'EOF'
# Nomad Server Policy for Consul Integration
service_prefix "" {
  policy = "write"
}

agent_prefix "" {
  policy = "read"
}

node_prefix "" {
  policy = "read"
}

key_prefix "" {
  policy = "write"
}

acl = "write"

event_prefix "" {
  policy = "write"
}

query_prefix "" {
  policy = "write"
}

session_prefix "" {
  policy = "write"
}
EOF

# Nomad Client Policy for Consul
cat > /tmp/nomad-client-policy.hcl << 'EOF'
# Nomad Client Policy for Consul Integration
service_prefix "" {
  policy = "write"
}

agent_prefix "" {
  policy = "read"
}

node_prefix "" {
  policy = "read"
}

key_prefix "" {
  policy = "write"
}

event_prefix "" {
  policy = "read"
}

query_prefix "" {
  policy = "read"
}

session_prefix "" {
  policy = "write"
}
EOF

# Anonymous Policy for public services
cat > /tmp/anonymous-policy.hcl << 'EOF'
# Anonymous Policy for public access
service_prefix "" {
  policy = "read"
}

node_prefix "" {
  policy = "read"
}

key_prefix "public/" {
  policy = "read"
}
EOF

# Application Policy Template
cat > /tmp/application-policy.hcl << 'EOF' 
# Application Policy Template
service "app" {
  policy = "write"
}

service "db" {
  policy = "write"
}

service "cache" {
  policy = "write"
}

service_prefix "web-" {
  policy = "write"
}

key_prefix "app/" {
  policy = "write"
}

session_prefix "" {
  policy = "write"
}

node_prefix "" {
  policy = "read"
}
EOF

echo "ACL policy files created in /tmp/"
echo "Use these with 'consul acl policy create' commands after bootstrap"