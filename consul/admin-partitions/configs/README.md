# Consul Admin Partitions - Gateway Configurations

This directory contains configurations for API Gateway and Mesh Gateway to enable cross-partition communication and external traffic routing.

## API Gateway Configuration

### Modern Consul API Gateway (v2)
The API Gateway replaces the deprecated Ingress Gateway and provides:
- **External traffic ingress** into the service mesh
- **HTTP/HTTPS routing** with path and host-based rules  
- **Cross-partition routing** for multi-tenant applications
- **Load balancing** across service instances

### Files:
- `api-gateway/gateway.yaml` - API Gateway resource definition
- `api-gateway/routes.yaml` - HTTP routes for services

### Usage:
```bash
# Apply API Gateway configuration
kubectl apply -f configs/api-gateway/

# Check API Gateway status
kubectl get apigateway -n default
kubectl get httproute -n development
```

## Mesh Gateway Configuration

### Cross-Partition Communication
Mesh Gateways enable secure communication between admin partitions:
- **WAN federation** between partitions
- **Service mesh traffic** routing between k8s-east and k8s-west
- **TLS encryption** for all cross-partition traffic
- **Service exports** for cross-partition service discovery

### Files:
- `mesh-gateway/mesh-gateway.yaml` - Mesh Gateway service and configuration
- `mesh-gateway/partition-exports.yaml` - Service exports between partitions

### Usage:
```bash
# Apply Mesh Gateway configuration
kubectl apply -f configs/mesh-gateway/

# Check Mesh Gateway status
kubectl get service mesh-gateway -n consul
kubectl get exportedservices -n consul
```

## Deployment Order

1. **Deploy Admin Partitions** (servers + clients)
2. **Apply Mesh Gateway configs** (enables cross-partition communication)
3. **Deploy demo applications** (fake-service frontend/backend)
4. **Apply API Gateway configs** (enables external access)
5. **Apply HTTP routes** (configures traffic routing)

## Testing Cross-Partition Communication

```bash
# Test service mesh connectivity between partitions
kubectl exec -it <frontend-pod> -n development -- curl http://backend.virtual.k8s-west.consul:9090

# Test API Gateway external access
curl http://<api-gateway-ip>:8080/api

# Test cross-partition routing via API Gateway
curl -H "Host: west.example.com" http://<api-gateway-ip>:8080/west
```

## Features Enabled

✅ **API Gateway** (modern replacement for Ingress Gateway)  
✅ **Mesh Gateway** (cross-partition communication)  
✅ **Service Exports** (cross-partition service discovery)  
✅ **HTTP Routes** (path and host-based routing)  
✅ **Load Balancer Services** (external access via GCP LB)  
✅ **TLS Encryption** (secure service mesh communication)  

This configuration provides a complete multi-tenant, cross-partition service mesh with external traffic ingress capabilities.