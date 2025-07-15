# ACL Policy for k8s-southwest1 Production Environment
# Restricted access for production environment in k8s-southwest1 partition

# Production namespace permissions
namespace "production" {
  policy = "write"
  intentions = "write"
}

# Service permissions - limited to production namespace
service_prefix "" {
  policy = "read"
}

# Enhanced service permissions for production namespace
namespace "production" {
  service_prefix "" {
    policy = "write"
    intentions = "write"
  }
}

# Node permissions - read access for service discovery
node_prefix "" {
  policy = "read"
}

# Key-value permissions - scoped to production (restricted)
key_prefix "production/" {
  policy = "write"
}

key_prefix "config/production/" {
  policy = "write"
}

# Session permissions for production
session_prefix "production-" {
  policy = "write"
}

# Limited mesh permissions
mesh = "read"

# Agent permissions - read only
agent_prefix "" {
  policy = "read"
}

# Query permissions for production
query_prefix "production-" {
  policy = "write"
}

# Additional production-specific restrictions
# No write access to global configs
key_prefix "global/" {
  policy = "deny"
}