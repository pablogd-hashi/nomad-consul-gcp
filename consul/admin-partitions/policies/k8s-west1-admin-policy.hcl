# ACL Policy for k8s-west1 Admin Partition
# Full administrative access within the k8s-west1 partition

# Partition-wide permissions
partition "k8s-west1" {
  policy = "write"
}

# Namespace permissions - full access to all namespaces in this partition
namespace_prefix "" {
  policy = "write"
  intentions = "write"
}

# Service permissions - full control over services
service_prefix "" {
  policy = "write"
  intentions = "write"
}

# Node permissions - required for service registration
node_prefix "" {
  policy = "write"
}

# Key-value permissions for configuration
key_prefix "" {
  policy = "write"
}

# Session permissions
session_prefix "" {
  policy = "write"
}

# Mesh and gateway permissions
mesh = "write"
peering = "write"

# Agent permissions for node operations
agent_prefix "" {
  policy = "write"
}

# Event permissions
event_prefix "" {
  policy = "write"
}

# Query permissions
query_prefix "" {
  policy = "write"
}

# API Gateway permissions
api_gateway_prefix "" {
  policy = "write"
}

# Catalog permissions
catalog = "write"