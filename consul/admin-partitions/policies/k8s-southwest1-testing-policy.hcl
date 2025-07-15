# ACL Policy for k8s-southwest1 Testing Environment
# Limited access for testing environment in k8s-southwest1 partition

# Testing namespace permissions
namespace "testing" {
  policy = "write"
  intentions = "write"
}

# Service permissions - limited to testing namespace
service_prefix "" {
  policy = "read"
}

# Enhanced service permissions for testing namespace
namespace "testing" {
  service_prefix "" {
    policy = "write"
    intentions = "write"
  }
}

# Node permissions - read access for service discovery
node_prefix "" {
  policy = "read"
}

# Key-value permissions - scoped to testing
key_prefix "testing/" {
  policy = "write"
}

key_prefix "config/testing/" {
  policy = "write"
}

# Session permissions for testing
session_prefix "testing-" {
  policy = "write"
}

# Limited mesh permissions
mesh = "read"

# Agent permissions - read only
agent_prefix "" {
  policy = "read"
}

# Query permissions for testing
query_prefix "testing-" {
  policy = "write"
}