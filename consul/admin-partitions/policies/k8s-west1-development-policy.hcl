# ACL Policy for k8s-west1 Development Environment
# Limited access for development environment in k8s-west1 partition

# Development namespace permissions
namespace "development" {
  policy = "write"
  intentions = "write"
}

# Service permissions - limited to development namespace
service_prefix "" {
  policy = "read"
}

# Enhanced service permissions for development namespace
namespace "development" {
  service_prefix "" {
    policy = "write"
    intentions = "write"
  }
}

# Node permissions - read access for service discovery
node_prefix "" {
  policy = "read"
}

# Key-value permissions - scoped to development
key_prefix "development/" {
  policy = "write"
}

key_prefix "config/development/" {
  policy = "write"
}

# Session permissions for development
session_prefix "development-" {
  policy = "write"
}

# Limited mesh permissions
mesh = "read"

# Agent permissions - read only
agent_prefix "" {
  policy = "read"
}

# Query permissions for development
query_prefix "development-" {
  policy = "write"
}