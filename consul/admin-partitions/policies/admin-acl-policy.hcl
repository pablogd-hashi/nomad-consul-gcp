# This policy grants full read/write access to all partitions and namespaces
# including the ability to manage Consul ACLs, services, and nodes.

# Full access to ACL operations
acl = "write"

# Full access to cluster-level operations
operator = "write"

partition_prefix "" {
  policy = "write"
  
  
  key_prefix "" {
    policy = "write"
  }

  service_prefix "" {
    policy = "write"
  }
  
  node_prefix "" {
    policy = "write"
  }
  
  namespace_prefix "" {
    acl = "write"

    policy = "write"

    key_prefix "" {
      policy = "write"
    }

    service_prefix "" {
      policy = "write"
    }

    node_prefix "" {
      policy = "read"
    }

  }
}

