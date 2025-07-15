# ACL Policy for k8s-west1 Acceptance Environment
# Limited access for acceptance environment in k8s-west1 partition

# Acceptance namespace permissions
namespace "acceptance" {
  policy = "write"
  intentions = "write"
}

# Service permissions - limited to acceptance namespace
service_prefix "" {
  policy = "read"
}

# Enhanced service permissions for acceptance namespace
namespace "acceptance" {
  service_prefix "" {
    policy = "write"
    intentions = "write"
  }
}

# Node permissions - read access for service discovery
node_prefix "" {
  policy = "read"
}

# Key-value permissions - scoped to acceptance
key_prefix "acceptance/" {
  policy = "write"
}

key_prefix "config/acceptance/" {
  policy = "write"
}

# Session permissions for acceptance
session_prefix "acceptance-" {
  policy = "write"
}

# Limited mesh permissions
mesh = "read"

# Agent permissions - read only
agent_prefix "" {
  policy = "read"
}

# Query permissions for acceptance
query_prefix "acceptance-" {
  policy = "write"
}