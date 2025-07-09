# Consul Enterprise: K8s Clusters with External Consul Servers

This demo connects 2 Kubernetes clusters to your existing Consul servers running in VMs, using admin partitions with DTAP namespaces.

## Architecture Overview

```
Consul Servers (VMs) - Enterprise
├── Admin Partition: "k8s-east" 
│   ├── Namespace: "development"
│   ├── Namespace: "testing" 
│   └── Namespace: "acceptance"
└── Admin Partition: "k8s-west"
    ├── Namespace: "development"
    ├── Namespace: "testing"
    └── Namespace: "production"
```

## Prerequisites

```bash
# Prepare two clusters
minikube start -p cluster-east --driver=docker --memory=4096 --cpus=2
minikube start -p cluster-west --driver=docker --memory=4096 --cpus=2

# Switch contexts
kubectl config use-context cluster-east
kubectl create namespace consul
kubectl config use-context cluster-west  
kubectl create namespace consul
```

## Step 1: Prepare Consul Servers (on your VMs)

On your Consul servers, ensure admin partitions are enabled:

```hcl
# /etc/consul.d/consul.hcl
datacenter = "dc1"
data_dir = "/opt/consul"
log_level = "INFO"
server = true
bootstrap_expect = 3  # adjust based on your server count

# Enterprise features
license_path = "/etc/consul.d/consul.hclic"
partition = "default"

# Enable admin partitions
experiments = ["admin-partitions"]

# API and UI
bind_addr = "0.0.0.0"
client_addr = "0.0.0.0"
ui_config {
  enabled = true
}

# Connect
connect {
  enabled = true
}

# ACLs
acl = {
  enabled = true
  default_policy = "deny"
  enable_token_persistence = true
}

# TLS
tls {
  defaults {
    verify_incoming = true
    verify_outgoing = true
    ca_file = "/etc/consul.d/ca.pem"
    cert_file = "/etc/consul.d/consul.pem"
    key_file = "/etc/consul.d/consul-key.pem"
  }
}
```

## Step 2: Create Admin Partitions on Consul Servers

```bash
# Replace CONSUL_SERVER_IP with your actual Consul server IP
export CONSUL_HTTP_ADDR="https://CONSUL_SERVER_IP:8500"
export CONSUL_HTTP_TOKEN="your-bootstrap-token"

# Create k8s-east partition
consul partition create -name="k8s-east" -description="Kubernetes East Cluster"

# Create k8s-west partition  
consul partition create -name="k8s-west" -description="Kubernetes West Cluster"

# Create namespaces in k8s-east
consul namespace create -name="development" -partition="k8s-east"
consul namespace create -name="testing" -partition="k8s-east"
consul namespace create -name="acceptance" -partition="k8s-east"

# Create namespaces in k8s-west
consul namespace create -name="development" -partition="k8s-west"
consul namespace create -name="testing" -partition="k8s-west"
consul namespace create -name="production" -partition="k8s-west"
```

## Step 3: Create ACL Policies and Tokens

### Create Partition-Specific Policies

```bash
# Create policy for k8s-east partition
consul acl policy create \
  -name="k8s-east-partition-policy" \
  -description="Policy for k8s-east partition" \
  -partition="k8s-east" \
  -rules='
partition_prefix "" {
  policy = "write"
}
namespace_prefix "" {
  policy = "write"
  intentions = "write"
  acl = "write"
}
node_prefix "" {
  policy = "write"
}
service_prefix "" {
  policy = "write"
  intentions = "write"
}
session_prefix "" {
  policy = "write"
}
agent_prefix "" {
  policy = "write"
}
query_prefix "" {
  policy = "write"
}
key_prefix "" {
  policy = "write"
}
operator = "write"
mesh = "write"
peering = "write"
'

# Create policy for k8s-west partition
consul acl policy create \
  -name="k8s-west-partition-policy" \
  -description="Policy for k8s-west partition" \
  -partition="k8s-west" \
  -rules='
partition_prefix "" {
  policy = "write"
}
namespace_prefix "" {
  policy = "write"
  intentions = "write"
  acl = "write"
}
node_prefix "" {
  policy = "write"
}
service_prefix "" {
  policy = "write"
  intentions = "write"
}
session_prefix "" {
  policy = "write"
}
agent_prefix "" {
  policy = "write"
}
query_prefix "" {
  policy = "write"
}
key_prefix "" {
  policy = "write"
}
operator = "write"
mesh = "write"
peering = "write"
'
```

### Generate Partition Tokens

```bash
# Create partition token for k8s-east
consul acl token create \
  -description="k8s-east partition token" \
  -partition="k8s-east" \
  -policy-name="k8s-east-partition-policy" > k8s-east-token.txt

# Create partition token for k8s-west
consul acl token create \
  -description="k8s-west partition token" \
  -partition="k8s-west" \
  -policy-name="k8s-west-partition-policy" > k8s-west-token.txt

# Extract tokens
EAST_TOKEN=$(cat k8s-east-token.txt | grep SecretID | awk '{print $2}')
WEST_TOKEN=$(cat k8s-west-token.txt | grep SecretID | awk '{print $2}')

# Verify tokens were created
echo "East Token: $EAST_TOKEN"
echo "West Token: $WEST_TOKEN"
```

### Alternative: Create More Restrictive Policies (Recommended for Production)

If you want more granular control, use these more restrictive policies instead:

```bash
# More restrictive policy for k8s-east
consul acl policy create \
  -name="k8s-east-restricted-policy" \
  -description="Restricted policy for k8s-east partition" \
  -partition="k8s-east" \
  -rules='
partition "k8s-east" {
  policy = "write"
}
namespace_prefix "" {
  policy = "write"
  intentions = "write"
}
node_prefix "" {
  policy = "write"
}
service_prefix "" {
  policy = "write"
  intentions = "write"
}
session_prefix "" {
  policy = "write"
}
agent_prefix "" {
  policy = "read"
}
key_prefix "k8s-east/" {
  policy = "write"
}
mesh = "write"
'

# More restrictive policy for k8s-west
consul acl policy create \
  -name="k8s-west-restricted-policy" \
  -description="Restricted policy for k8s-west partition" \
  -partition="k8s-west" \
  -rules='
partition "k8s-west" {
  policy = "write"
}
namespace_prefix "" {
  policy = "write"
  intentions = "write"
}
node_prefix "" {
  policy = "write"
}
service_prefix "" {
  policy = "write"
  intentions = "write"
}
session_prefix "" {
  policy = "write"
}
agent_prefix "" {
  policy = "read"
}
key_prefix "k8s-west/" {
  policy = "write"
}
mesh = "write"
'
```

## Step 4: Deploy Consul Clients to K8s Clusters

### Cluster East Configuration

```yaml
# consul-east-values.yaml
global:
  name: consul
  datacenter: dc1
  adminPartitions:
    enabled: true
    name: "k8s-east"
  
  # External servers
  server:
    enabled: false
  
  # Connect to external Consul servers
  externalServers:
    enabled: true
    hosts: ["CONSUL_SERVER_IP1", "CONSUL_SERVER_IP2", "CONSUL_SERVER_IP3"]
    httpsPort: 8500
    grpcPort: 8502
    tlsServerName: "consul.service.consul"
    useSystemRoots: false
    k8sAuthMethodHost: "https://cluster-east-k8s-api:6443"
  
  acls:
    manageSystemACLs: false
    bootstrapToken:
      secretName: consul-bootstrap-token
      secretKey: token
  
  tls:
    enabled: true
    enableAutoEncrypt: true
    caCert:
      secretName: consul-ca-cert
      secretKey: tls.crt

client:
  enabled: true
  grpc: true
  exposeGossipPorts: true
  join: ["CONSUL_SERVER_IP1", "CONSUL_SERVER_IP2", "CONSUL_SERVER_IP3"]

connectInject:
  enabled: true
  default: false
  transparentProxy:
    defaultEnabled: false
  consulNamespaces:
    consulDestinationNamespace: "development"  # default namespace
    mirroringK8S: false

apiGateway:
  enabled: true
  managedGatewayClass:
    enabled: true
```

### Cluster West Configuration

```yaml
# consul-west-values.yaml
global:
  name: consul
  datacenter: dc1
  adminPartitions:
    enabled: true
    name: "k8s-west"
  
  # External servers
  server:
    enabled: false
  
  # Connect to external Consul servers
  externalServers:
    enabled: true
    hosts: ["CONSUL_SERVER_IP1", "CONSUL_SERVER_IP2", "CONSUL_SERVER_IP3"]
    httpsPort: 8500
    grpcPort: 8502
    tlsServerName: "consul.service.consul"
    useSystemRoots: false
    k8sAuthMethodHost: "https://cluster-west-k8s-api:6443"
  
  acls:
    manageSystemACLs: false
    bootstrapToken:
      secretName: consul-bootstrap-token
      secretKey: token
  
  tls:
    enabled: true
    enableAutoEncrypt: true
    caCert:
      secretName: consul-ca-cert
      secretKey: tls.crt

client:
  enabled: true
  grpc: true
  exposeGossipPorts: true
  join: ["CONSUL_SERVER_IP1", "CONSUL_SERVER_IP2", "CONSUL_SERVER_IP3"]

connectInject:
  enabled: true
  default: false
  transparentProxy:
    defaultEnabled: false
  consulNamespaces:
    consulDestinationNamespace: "development"  # default namespace
    mirroringK8S: false

apiGateway:
  enabled: true
  managedGatewayClass:
    enabled: true
```

## Step 5: Create Required Secrets

### For Cluster East:
```bash
kubectl config use-context cluster-east

# Bootstrap token
kubectl create secret generic consul-bootstrap-token \
  --from-literal=token="$EAST_TOKEN" \
  -n consul

# CA certificate (copy from your Consul servers)
kubectl create secret generic consul-ca-cert \
  --from-file=tls.crt=/path/to/consul-ca.pem \
  -n consul
```

### For Cluster West:
```bash
kubectl config use-context cluster-west

# Bootstrap token
kubectl create secret generic consul-bootstrap-token \
  --from-literal=token="$WEST_TOKEN" \
  -n consul

# CA certificate (copy from your Consul servers)
kubectl create secret generic consul-ca-cert \
  --from-file=tls.crt=/path/to/consul-ca.pem \
  -n consul
```

## Step 6: Deploy Consul to Both Clusters

```bash
# Add Consul Helm repo
helm repo add hashicorp https://helm.releases.hashicorp.com
helm repo update

# Deploy to cluster-east
kubectl config use-context cluster-east
helm install consul hashicorp/consul -n consul -f consul-east-values.yaml

# Deploy to cluster-west
kubectl config use-context cluster-west
helm install consul hashicorp/consul -n consul -f consul-west-values.yaml
```

## Step 7: Deploy DTAP Applications

### East Cluster - Development Environment

```yaml
# east-development-app.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ecommerce-dev
  namespace: consul
spec:
  replicas: 1
  selector:
    matchLabels:
      app: ecommerce-dev
  template:
    metadata:
      labels:
        app: ecommerce-dev
      annotations:
        consul.hashicorp.com/connect-inject: "true"
        consul.hashicorp.com/partition: "k8s-east"
        consul.hashicorp.com/namespace: "development"
        consul.hashicorp.com/service-name: "ecommerce-api"
        consul.hashicorp.com/service-tags: "version=dev,environment=development"
    spec:
      containers:
      - name: ecommerce-api
        image: nginx:alpine
        ports:
        - containerPort: 80
        env:
        - name: ENVIRONMENT
          value: "development"
        - name: VERSION
          value: "1.0.0-dev"
        command: ["/bin/sh"]
        args: ["-c", "echo '<h1>E-commerce API</h1><h2>Environment: Development</h2><p>Partition: k8s-east</p><p>Namespace: development</p><p>Version: 1.0.0-dev</p>' > /usr/share/nginx/html/index.html && nginx -g 'daemon off;'"]
---
apiVersion: v1
kind: Service
metadata:
  name: ecommerce-dev
  namespace: consul
spec:
  selector:
    app: ecommerce-dev
  ports:
  - port: 80
    targetPort: 80
```

### East Cluster - Testing Environment

```yaml
# east-testing-app.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ecommerce-test
  namespace: consul
spec:
  replicas: 1
  selector:
    matchLabels:
      app: ecommerce-test
  template:
    metadata:
      labels:
        app: ecommerce-test
      annotations:
        consul.hashicorp.com/connect-inject: "true"
        consul.hashicorp.com/partition: "k8s-east"
        consul.hashicorp.com/namespace: "testing"
        consul.hashicorp.com/service-name: "ecommerce-api"
        consul.hashicorp.com/service-tags: "version=test,environment=testing"
    spec:
      containers:
      - name: ecommerce-api
        image: nginx:alpine
        ports:
        - containerPort: 80
        env:
        - name: ENVIRONMENT
          value: "testing"
        - name: VERSION
          value: "1.0.0-rc1"
        command: ["/bin/sh"]
        args: ["-c", "echo '<h1>E-commerce API</h1><h2>Environment: Testing</h2><p>Partition: k8s-east</p><p>Namespace: testing</p><p>Version: 1.0.0-rc1</p>' > /usr/share/nginx/html/index.html && nginx -g 'daemon off;'"]
---
apiVersion: v1
kind: Service
metadata:
  name: ecommerce-test
  namespace: consul
spec:
  selector:
    app: ecommerce-test
  ports:
  - port: 80
    targetPort: 80
```

### East Cluster - Acceptance Environment

```yaml
# east-acceptance-app.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ecommerce-acc
  namespace: consul
spec:
  replicas: 2
  selector:
    matchLabels:
      app: ecommerce-acc
  template:
    metadata:
      labels:
        app: ecommerce-acc
      annotations:
        consul.hashicorp.com/connect-inject: "true"
        consul.hashicorp.com/partition: "k8s-east"
        consul.hashicorp.com/namespace: "acceptance"
        consul.hashicorp.com/service-name: "ecommerce-api"
        consul.hashicorp.com/service-tags: "version=stable,environment=acceptance"
    spec:
      containers:
      - name: ecommerce-api
        image: nginx:alpine
        ports:
        - containerPort: 80
        env:
        - name: ENVIRONMENT
          value: "acceptance"
        - name: VERSION
          value: "1.0.0"
        command: ["/bin/sh"]
        args: ["-c", "echo '<h1>E-commerce API</h1><h2>Environment: Acceptance</h2><p>Partition: k8s-east</p><p>Namespace: acceptance</p><p>Version: 1.0.0</p>' > /usr/share/nginx/html/index.html && nginx -g 'daemon off;'"]
---
apiVersion: v1
kind: Service
metadata:
  name: ecommerce-acc
  namespace: consul
spec:
  selector:
    app: ecommerce-acc
  ports:
  - port: 80
    targetPort: 80
```

### West Cluster Applications

```yaml
# west-apps.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: payment-dev
  namespace: consul
spec:
  replicas: 1
  selector:
    matchLabels:
      app: payment-dev
  template:
    metadata:
      labels:
        app: payment-dev
      annotations:
        consul.hashicorp.com/connect-inject: "true"
        consul.hashicorp.com/partition: "k8s-west"
        consul.hashicorp.com/namespace: "development"
        consul.hashicorp.com/service-name: "payment-service"
        consul.hashicorp.com/service-tags: "version=dev,environment=development"
    spec:
      containers:
      - name: payment-service
        image: nginx:alpine
        ports:
        - containerPort: 80
        command: ["/bin/sh"]
        args: ["-c", "echo '<h1>Payment Service</h1><h2>Environment: Development</h2><p>Partition: k8s-west</p><p>Namespace: development</p>' > /usr/share/nginx/html/index.html && nginx -g 'daemon off;'"]
---
apiVersion: v1
kind: Service
metadata:
  name: payment-dev
  namespace: consul
spec:
  selector:
    app: payment-dev
  ports:
  - port: 80
    targetPort: 80
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: payment-test
  namespace: consul
spec:
  replicas: 1
  selector:
    matchLabels:
      app: payment-test
  template:
    metadata:
      labels:
        app: payment-test
      annotations:
        consul.hashicorp.com/connect-inject: "true"
        consul.hashicorp.com/partition: "k8s-west"
        consul.hashicorp.com/namespace: "testing"
        consul.hashicorp.com/service-name: "payment-service"
        consul.hashicorp.com/service-tags: "version=test,environment=testing"
    spec:
      containers:
      - name: payment-service
        image: nginx:alpine
        ports:
        - containerPort: 80
        command: ["/bin/sh"]
        args: ["-c", "echo '<h1>Payment Service</h1><h2>Environment: Testing</h2><p>Partition: k8s-west</p><p>Namespace: testing</p>' > /usr/share/nginx/html/index.html && nginx -g 'daemon off;'"]
---
apiVersion: v1
kind: Service
metadata:
  name: payment-test
  namespace: consul
spec:
  selector:
    app: payment-test
  ports:
  - port: 80
    targetPort: 80
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: payment-prod
  namespace: consul
spec:
  replicas: 3
  selector:
    matchLabels:
      app: payment-prod
  template:
    metadata:
      labels:
        app: payment-prod
      annotations:
        consul.hashicorp.com/connect-inject: "true"
        consul.hashicorp.com/partition: "k8s-west"
        consul.hashicorp.com/namespace: "production"
        consul.hashicorp.com/service-name: "payment-service"
        consul.hashicorp.com/service-tags: "version=stable,environment=production"
    spec:
      containers:
      - name: payment-service
        image: nginx:alpine
        ports:
        - containerPort: 80
        command: ["/bin/sh"]
        args: ["-c", "echo '<h1>Payment Service</h1><h2>Environment: Production</h2><p>Partition: k8s-west</p><p>Namespace: production</p>' > /usr/share/nginx/html/index.html && nginx -g 'daemon off;'"]
---
apiVersion: v1
kind: Service
metadata:
  name: payment-prod
  namespace: consul
spec:
  selector:
    app: payment-prod
  ports:
  - port: 80
    targetPort: 80
```

## Step 8: Deploy Applications

```bash
# Deploy to East cluster
kubectl config use-context cluster-east
kubectl apply -f east-development-app.yaml
kubectl apply -f east-testing-app.yaml
kubectl apply -f east-acceptance-app.yaml

# Deploy to West cluster
kubectl config use-context cluster-west
kubectl apply -f west-apps.yaml
```

## Step 9: Create API Gateway Configurations

### East Cluster Gateway

```yaml
# east-gateway.yaml
apiVersion: gateway.networking.k8s.io/v1beta1
kind: Gateway
metadata:
  name: east-gateway
  namespace: consul
  annotations:
    consul.hashicorp.com/partition: "k8s-east"
spec:
  gatewayClassName: consul-api-gateway
  listeners:
  - name: dev-listener
    port: 8080
    protocol: HTTP
  - name: test-listener
    port: 8081
    protocol: HTTP
  - name: acc-listener
    port: 8082
    protocol: HTTP
---
apiVersion: gateway.networking.k8s.io/v1beta1
kind: HTTPRoute
metadata:
  name: east-dev-route
  namespace: consul
spec:
  parentRefs:
  - name: east-gateway
    sectionName: dev-listener
  rules:
  - matches:
    - path:
        type: PathPrefix
        value: /
    backendRefs:
    - name: ecommerce-dev
      port: 80
---
apiVersion: gateway.networking.k8s.io/v1beta1
kind: HTTPRoute
metadata:
  name: east-test-route
  namespace: consul
spec:
  parentRefs:
  - name: east-gateway
    sectionName: test-listener
  rules:
  - matches:
    - path:
        type: PathPrefix
        value: /
    backendRefs:
    - name: ecommerce-test
      port: 80
---
apiVersion: gateway.networking.k8s.io/v1beta1
kind: HTTPRoute
metadata:
  name: east-acc-route
  namespace: consul
spec:
  parentRefs:
  - name: east-gateway
    sectionName: acc-listener
  rules:
  - matches:
    - path:
        type: PathPrefix
        value: /
    backendRefs:
    - name: ecommerce-acc
      port: 80
```

### West Cluster Gateway

```yaml
# west-gateway.yaml
apiVersion: gateway.networking.k8s.io/v1beta1
kind: Gateway
metadata:
  name: west-gateway
  namespace: consul
  annotations:
    consul.hashicorp.com/partition: "k8s-west"
spec:
  gatewayClassName: consul-api-gateway
  listeners:
  - name: dev-listener
    port: 8080
    protocol: HTTP
  - name: test-listener
    port: 8081
    protocol: HTTP
  - name: prod-listener
    port: 8082
    protocol: HTTP
---
apiVersion: gateway.networking.k8s.io/v1beta1
kind: HTTPRoute
metadata:
  name: west-dev-route
  namespace: consul
spec:
  parentRefs:
  - name: west-gateway
    sectionName: dev-listener
  rules:
  - matches:
    - path:
        type: PathPrefix
        value: /
    backendRefs:
    - name: payment-dev
      port: 80
---
apiVersion: gateway.networking.k8s.io/v1beta1
kind: HTTPRoute
metadata:
  name: west-test-route
  namespace: consul
spec:
  parentRefs:
  - name: west-gateway
    sectionName: test-listener
  rules:
  - matches:
    - path:
        type: PathPrefix
        value: /
    backendRefs:
    - name: payment-test
      port: 80
---
apiVersion: gateway.networking.k8s.io/v1beta1
kind: HTTPRoute
metadata:
  name: west-prod-route
  namespace: consul
spec:
  parentRefs:
  - name: west-gateway
    sectionName: prod-listener
  rules:
  - matches:
    - path:
        type: PathPrefix
        value: /
    backendRefs:
    - name: payment-prod
      port: 80
```

## Step 10: Deploy Gateways

```bash
# Deploy East gateway
kubectl config use-context cluster-east
kubectl apply -f east-gateway.yaml

# Deploy West gateway
kubectl config use-context cluster-west
kubectl apply -f west-gateway.yaml
```

## Step 11: Test the Setup

### Port Forward and Test East Cluster
```bash
kubectl config use-context cluster-east
kubectl port-forward -n consul svc/east-gateway 8080:8080 8081:8081 8082:8082 &

# Test development
curl http://localhost:8080/

# Test testing
curl http://localhost:8081/

# Test acceptance
curl http://localhost:8082/
```

### Port Forward and Test West Cluster
```bash
kubectl config use-context cluster-west
kubectl port-forward -n consul svc/west-gateway 9080:8080 9081:8081 9082:8082 &

# Test development
curl http://localhost:9080/

# Test testing
curl http://localhost:9081/

# Test production
curl http://localhost:9082/
```

## Step 12: Verify in Consul UI

Access your Consul UI at `https://CONSUL_SERVER_IP:8500` and verify:

1. **Admin Partitions**: `k8s-east` and `k8s-west` are visible
2. **Namespaces**: Each partition shows its DTAP namespaces
3. **Services**: Each service appears in the correct partition/namespace
4. **Service Mesh**: Connect sidecars are properly registered
5. **API Gateways**: Gateway configurations are visible

## Key Benefits Demonstrated

1. **Partition Isolation**: Services in k8s-east cannot communicate with k8s-west
2. **DTAP Structure**: Clear separation of environments within each partition
3. **Service Mesh**: Automatic sidecar injection and service discovery
4. **API Gateway Routing**: Environment-specific routing within each partition
5. **Multi-Cluster Management**: Centralized control from Consul servers

## Cleanup

```bash
# Clean up port forwards
pkill -f "kubectl port-forward"

# Clean up clusters
kubectl config use-context cluster-east
helm uninstall consul -n consul

kubectl config use-context cluster-west
helm uninstall consul -n consul

# Delete minikube clusters
minikube delete -p cluster-east
minikube delete -p cluster-west
```

This setup demonstrates a production-ready architecture with proper partition isolation, DTAP environments, and centralized Consul management!