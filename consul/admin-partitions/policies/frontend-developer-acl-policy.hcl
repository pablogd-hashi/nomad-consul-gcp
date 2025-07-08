# This policy grants access to the web partition and the frontend* namespaces

partition "web" {
  # Write access to the web admin partition
  policy = "write"
  
  # grants write permissions to the web admin partition
  key_prefix "" {
    policy = "write"
  }

  # grants service:write to the web admin partition
  service_prefix "" {
    policy = "write"
  }
  
  # grants node:write to the web admin partition
  node_prefix "" {
    policy = "read"
  }
  
  namespace_prefix "frontend" {
    # grants permission to manage ACLs only for the frontend* namespaces
    acl = "write"

    # grants permission to create and edit the frontend* namespaces
    policy = "write"

    # grants write permissions to the KV for the frontend* namespaces
    key_prefix "" {
      policy = "write"
    }

    # grants service:write for all services in the frontend* namespaces
    service_prefix "" {
      policy = "write"
    }

    # grants node:read in the frontend* namespaces
    node_prefix "" {
      policy = "read"
    }

  }
}

