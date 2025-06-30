# Consul Connect Configuration for Service Mesh

# Global Connect settings
connect {
  enabled = true
  
  # Enable local connect proxy
  enable_mesh_gateway_wan_federation = false
  
  ca_config {
    provider = "consul"
    
    config {
      # Root certificate settings
      leaf_cert_ttl = "72h"
      root_cert_ttl = "8760h" # 1 year
      rotation_period = "2160h" # 90 days
      intermediate_cert_ttl = "4380h" # 6 months
    }
  }
}

# Mesh gateway configuration
service {
  name = "mesh-gateway"
  kind = "mesh-gateway"
  port = 8443
  
  proxy {
    config {
      envoy_gateway_bind_addresses {
        wan = "0.0.0.0:8443"
      }
    }
  }
  
  check {
    name = "Mesh Gateway Listening"
    tcp = "127.0.0.1:8443"
    interval = "10s"
    timeout = "3s"
  }
}

# Default proxy configuration
config_entries {
  bootstrap = [
    {
      kind = "proxy-defaults"
      name = "global"
      
      config {
        # Envoy proxy configuration
        envoy_prometheus_bind_addr = "0.0.0.0:9102"
        
        # Protocol settings
        protocol = "http"
        
        # Connect timeout
        connect_timeout_ms = 5000
        
        # Upstream configuration
        upstream_config {
          defaults {
            connect_timeout_ms = 5000
            protocol = "http"
          }
        }
      }
    },
    {
      kind = "service-defaults"
      name = "*"
      
      protocol = "http"
      
      mesh_gateway {
        mode = "local"
      }
      
      transparent_proxy {
        outbound_listener_port = 15001
        dialed_directly = true
      }
    }
  ]
}