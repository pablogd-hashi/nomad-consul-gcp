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

### Understanding ACL Policies in Admin Partitions

Before creating the policies, let's understand what these rules actually do in your Kubernetes + Consul setup:

#### **Policy Rules Explained**

**`namespace_prefix ""`** - **DTAP Environment Management**
```hcl
namespace_prefix "" {
  policy = "write"
  intentions = "write" 
  acl = "write"
}
```
- Creates/manages Consul namespaces (development, testing, acceptance, production)
- Sets service intentions (which services can talk to each other)
- Manages ACL tokens for services within those namespaces
- **Demo Impact**: Enables your DTAP structure and service-to-service security policies

**`node_prefix ""`** - **Kubernetes Node Integration**
```hcl
node_prefix "" {
  policy = "write"
}
```
- Registers Kubernetes nodes as Consul clients
- Updates node health status and metadata
- Manages node-level services and health checks
- **Demo Impact**: Your minikube nodes appear in Consul's node catalog

**`service_prefix ""`** - **Service Mesh Core**
```hcl
service_prefix "" {
  policy = "write"
  intentions = "write"
}
```
- Registers services (ecommerce-api, payment-service, etc.) with Consul
- Updates service health and metadata
- Creates service-to-service communication rules (intentions)
- Manages Connect sidecar proxies
- **Demo Impact**: Your nginx services show up in Consul and can communicate securely

**`key_prefix ""`** - **Configuration Storage**
```hcl
key_prefix "" {
  policy = "write"
}
```
- Stores configuration data in Consul's key-value store
- Manages Connect certificates and configuration
- Stores service mesh policies and routing rules
- **Demo Impact**: API Gateway configurations and mesh certificates are stored here

**`mesh = "write"`** - **Service Mesh Control**
- Manages service mesh configuration (Connect)
- Controls sidecar proxy settings
- Manages mesh-wide policies like default deny/allow
- **Demo Impact**: Enables the Connect sidecars providing mTLS between services

**`session_prefix ""`** - **Distributed Coordination**
```hcl
session_prefix "" {
  policy = "write"
}
```
- Distributed locking for coordination
- Leader election for clustered services
- Coordination between multiple instances
- **Demo Impact**: Used internally by Consul for reliability and coordination

**`agent_prefix ""`** - **Agent Communication**
```hcl
agent_prefix "" {
  policy = "write"
}
```
- Controls Consul agent operations
- Manages local agent configuration
- Handles agent-to-server communication
- **Demo Impact**: Consul agents in Kubernetes pods communicate with your VM servers

**`peering = "write"`** - **Cross-Cluster Communication**
- Creates connections to other Consul clusters
- Manages cross-cluster service sharing
- Controls what services are exported/imported
- **Demo Impact**: Enables future cross-partition communication if needed

#### **Security Boundaries**
These policies are **partition-scoped**, meaning:
- ✅ **Full autonomy** within the assigned partition (k8s-east or k8s-west)
- ❌ **Cannot see or affect** other partitions
- ❌ **Cannot create** new partitions
- ❌ **Cannot perform** global operations

**Rules NOT allowed in partitioned policies:**
- `partition_prefix` - Can't manage partitions from within a partition
- `query_prefix` - Prepared queries not supported in partitions
- `operator` - Global operator permissions not allowed

### Create Partition-Specific Policies

```bash
# Create policy for k8s-east partition
consul acl policy create \
  -name="k8s-east-partition-policy" \
  -description="Policy for k8s-east partition" \
  -partition="k8s-east" \
  -rules='
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
key_prefix "" {
  policy = "write"
}
mesh = "write"
peering = "write"
'

# Create policy for k8s-west partition  
consul acl policy create \
  -name="k8s-west-partition-policy" \
  -description="Policy for k8s-west partition" \
  -partition="k8s-west" \
  -rules='
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
key_prefix "" {
  policy = "write"
}
mesh = "write"
peering = "write"
'
```

#### **What Happens When Kubernetes Pods Start**
With these policies, when a Kubernetes pod starts up:

1. **Node Registration**: "Hi Consul, I'm a new node in k8s-east partition"
2. **Service Registration**: "I'm running ecommerce-api in the development namespace" 
3. **Mesh Enrollment**: "Please give me a Connect sidecar with mTLS certificates"
4. **Intention Setup**: "Allow user-service to call me, deny everything else"
5. **Config Storage**: "Store my API gateway routes in the KV store"

**Without these policies**, your services would:
- ❌ Fail to register with Consul
- ❌ Not get service mesh capabilities  
- ❌ Can't create security policies
- ❌ No service discovery
- ❌ No API gateway functionality

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

### Alternative: Even Simpler Policy (If issues persist)

If you're still having issues, try this minimal policy that focuses on core Kubernetes + Consul functionality:

```bash
# Minimal policy for k8s-east
consul acl policy create \
  -name="k8s-east-minimal-policy" \
  -description="Minimal policy for k8s-east partition" \
  -partition="k8s-east" \
  -rules='
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
key_prefix "" {
  policy = "write"
}
mesh = "write"
'

# Minimal policy for k8s-west
consul acl policy create \
  -name="k8s-west-minimal-policy" \
  -description="Minimal policy for k8s-west partition" \
  -partition="k8s-west" \
  -rules='
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
key_prefix "" {
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
  enabled: false
  datacenter: dc1
  name: consul
  image: hashicorp/consul-enterprise:1.18.3
  imageK8S: hashicorp/consul-k8s-control-plane:1.4.6
  logLevel: debug
  tls:
    enabled: false
  acls:
    manageSystemACLs: true
    bootstrapToken:
      secretName: consul-bootstrap-token
      secretKey: key
  adminPartitions:
    enabled: true
    name: "k8s-east"
  metrics:
    enabled: true
    enableGatewayMetrics: true
  enableConsulNamespaces: true
  enterpriseLicense:
    secretName: consul-ent-license
    secretKey: key

externalServers:
  enabled: true
  hosts: ['34.78.193.136', '104.155.76.9', '35.233.57.96']
  tlsServerName: null
  httpsPort: 8500
  k8sAuthMethodHost: 'https://kubernetes.default.svc'

syncCatalog:
  enabled: true

meshGateway:
  enabled: true
  enableHealthChecks: false
  replicas: 1
  service:
    enabled: true
    type: NodePort
    nodePort: 32443

connectInject:
  transparentProxy:
    defaultEnabled: true
  enabled: true
  consulNamespaces:
    mirroringK8S: true
  apiGateway:
    managedGatewayClass:
      serviceType: NodePort

dns:
  enabled: true
```

### Cluster West Configuration

```yaml
# consul-west-values.yaml
global:
  enabled: false
  datacenter: dc1
  name: consul
  image: hashicorp/consul-enterprise:1.18.3
  imageK8S: hashicorp/consul-k8s-control-plane:1.4.6
  logLevel: debug
  tls:
    enabled: false
  acls:
    manageSystemACLs: true
    bootstrapToken:
      secretName: consul-bootstrap-token
      secretKey: key
  adminPartitions:
    enabled: true
    name: "k8s-west"
  metrics:
    enabled: true
    enableGatewayMetrics: true
  enableConsulNamespaces: true
  enterpriseLicense:
    secretName: consul-ent-license
    secretKey: key

externalServers:
  enabled: true
  hosts: ['34.78.193.136', '104.155.76.9', '35.233.57.96']
  tlsServerName: null
  httpsPort: 8500
  k8sAuthMethodHost: 'https://kubernetes.default.svc'

syncCatalog:
  enabled: true

meshGateway:
  enabled: true
  enableHealthChecks: false
  replicas: 1
  service:
    enabled: true
    type: NodePort
    nodePort: 32444

connectInject:
  transparentProxy:
    defaultEnabled: true
  enabled: true
  consulNamespaces:
    mirroringK8S: true
  apiGateway:
    managedGatewayClass:
      serviceType: NodePort

dns:
  enabled: true
```

### Alternative: Disable partition-init if still having issues

If the partition-init job continues to fail, you can disable it and create partitions manually:

```yaml
# Add this to both configurations if needed
partitionInit:
  enabled: false
```

Then create partitions manually on your Consul servers:

```bash
export CONSUL_HTTP_ADDR="http://34.78.193.136:8500"
export CONSUL_HTTP_TOKEN="your-bootstrap-token"

consul partition create -name="k8s-east" -description="Kubernetes East Cluster"
consul partition create -name="k8s-west" -description="Kubernetes West Cluster"
consul partition list
```

### Cluster West Configuration

```yaml
# consul-west-values.yaml
global:
  name: consul
  datacenter: dc1
  
  # Enterprise License
  enterpriseLicense:
    secretName: consul-enterprise-license
    secretKey: key
  
  # Admin Partitions (Enterprise feature)
  adminPartitions:
    enabled: true
    name: "k8s-west"
  
  # External Consul servers - REQUIRED for admin partitions
  externalServers:
    enabled: true
    hosts: ["34.78.193.136", "104.155.76.9", "35.233.57.96"]
    httpsPort: 8500
    grpcPort: 8502
    tlsServerName: null
    useSystemRoots: false
    k8sAuthMethodHost: "https://kubernetes.default.svc"
  
  # ACL Configuration
  acls:
    manageSystemACLs: false
    bootstrapToken:
      secretName: consul-bootstrap-token
      secretKey: token
  
  # TLS Configuration (disabled for your setup)
  tls:
    enabled: false
  
  # Image configuration for Enterprise
  image: "hashicorp/consul-enterprise:1.19.0-ent"
  imageK8S: "hashicorp/consul-k8s-control-plane:1.5.0"

# Disable server deployment (using external servers)
server:
  enabled: false

# Enable clients
client:
  enabled: true
  grpc: true
  exposeGossipPorts: true
  join: ["34.78.193.136", "104.155.76.9", "35.233.57.96"]
  extraConfig: |
    {
      "partition": "k8s-west",
      "retry_join": ["34.78.193.136", "104.155.76.9", "35.233.57.96"]
    }

# UI (optional, can disable if not needed)
ui:
  enabled: false

# Service Mesh Configuration
connectInject:
  enabled: true
  default: false
  k8sAllowNamespaces: ["*"]
  k8sDenyNamespaces: []
  
  # Consul Namespaces
  consulNamespaces:
    consulDestinationNamespace: "development"
    mirroringK8S: false
    mirroringK8SPrefix: ""
  
  # Transparent Proxy
  transparentProxy:
    defaultEnabled: false
    defaultOverwriteProbes: false
  
  # API Gateway (Enterprise feature)
  apiGateway:
    enabled: true
    managedGatewayClass:
      enabled: true
      nodeSelector: null
      serviceType: LoadBalancer
      useHostPorts: true
      copyAnnotations:
        service:
          annotations: |
            consul.hashicorp.com/partition: k8s-west
  
  # Metrics and observability
  metrics:
    defaultEnabled: true
    defaultEnableMerging: false
  
  # Resource settings
  resources:
    requests:
      memory: "50Mi"
      cpu: "50m"
    limits:
      memory: "100Mi"
      cpu: "100m"

# Partition initialization job
partitionInit:
  enabled: true

# Ingress Gateway (optional)
ingressGateways:
  enabled: false

# Terminating Gateway (optional)  
terminatingGateways:
  enabled: false

# Mesh Gateway (for WAN federation if needed)
meshGateway:
  enabled: false

# Prometheus metrics
prometheus:
  enabled: false

# Grafana dashboard
grafana:
  enabled: false
```

### Important: Deploy Order for Admin Partitions

When using admin partitions with external servers, you need to deploy in the right order:

```bash
# 1. Make sure your partitions exist on the Consul servers first
export CONSUL_HTTP_ADDR="http://34.78.193.136:8500"
export CONSUL_HTTP_TOKEN="your-bootstrap-token"

# Verify partitions exist
consul partition list

# If they don't exist, create them:
consul partition create -name="k8s-east" -description="Kubernetes East Cluster"
consul partition create -name="k8s-west" -description="Kubernetes West Cluster"

# 2. Then deploy to Kubernetes
kubectl config use-context cluster-east
helm install consul hashicorp/consul -n consul -f consul-east-values.yaml

kubectl config use-context cluster-west
helm install consul hashicorp/consul -n consul -f consul-west-values.yaml
```

## Step 5: Create Required Secrets

### Create Enterprise License Secret

First, create the Consul Enterprise license secret in both clusters:

```bash
# Create license secret for cluster-east
kubectl config use-context cluster-east
kubectl create secret generic consul-enterprise-license \
  --from-literal=key="YOUR_CONSUL_ENTERPRISE_LICENSE_KEY_HERE" \
  -n consul

# Create license secret for cluster-west  
kubectl config use-context cluster-west
kubectl create secret generic consul-enterprise-license \
  --from-literal=key="YOUR_CONSUL_ENTERPRISE_LICENSE_KEY_HERE" \
  -n consul
```

### Create Bootstrap Token Secrets

```bash
# For Cluster East
kubectl config use-context cluster-east
kubectl create secret generic consul-bootstrap-token \
  --from-literal=token="$EAST_TOKEN" \
  -n consul

# Verify secrets were created
kubectl get secrets -n consul
kubectl describe secret consul-bootstrap-token -n consul
kubectl describe secret consul-enterprise-license -n consul
```

```bash
# For Cluster West
kubectl config use-context cluster-west
kubectl create secret generic consul-bootstrap-token \
  --from-literal=token="$WEST_TOKEN" \
  -n consul

# Verify secrets were created
kubectl get secrets -n consul
kubectl describe secret consul-bootstrap-token -n consul
kubectl describe secret consul-enterprise-license -n consul
```

### Test Connectivity to Consul Servers

Before deploying, verify that your Kubernetes clusters can reach your Consul servers:

```bash
# Test from cluster-east
kubectl config use-context cluster-east
kubectl run test-connectivity --image=curlimages/curl --rm -it --restart=Never -- \
  curl -s http://34.78.193.136:8500/v1/status/leader

# Test from cluster-west
kubectl config use-context cluster-west
kubectl run test-connectivity --image=curlimages/curl --rm -it --restart=Never -- \
  curl -s http://34.78.193.136:8500/v1/status/leader

# You should see the leader IP returned, like: "34.78.193.136:8300"
```

### Verify Your Consul Enterprise License

```bash
# Check license status on your Consul servers
export CONSUL_HTTP_ADDR="http://34.78.193.136:8500"
export CONSUL_HTTP_TOKEN="your-bootstrap-token"

# Check license information
consul license get

# You should see output showing:
# - License ID
# - Customer ID  
# - Installation ID
# - Issue time
# - Start time
# - Expiration time
# - Features (should include "Admin Partitions")
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

## Step 9: Deploy Additional Services for Routing Demo

Let's add more services to demonstrate service-to-service routing through the API Gateway:

### East Cluster - Additional Services

```yaml
# east-additional-services.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: user-service-dev
  namespace: consul
spec:
  replicas: 1
  selector:
    matchLabels:
      app: user-service-dev
  template:
    metadata:
      labels:
        app: user-service-dev
      annotations:
        consul.hashicorp.com/connect-inject: "true"
        consul.hashicorp.com/partition: "k8s-east"
        consul.hashicorp.com/namespace: "development"
        consul.hashicorp.com/service-name: "user-service"
        consul.hashicorp.com/service-tags: "version=dev,environment=development"
        consul.hashicorp.com/connect-service-upstreams: "ecommerce-api:9001"
    spec:
      containers:
      - name: user-service
        image: nginx:alpine
        ports:
        - containerPort: 80
        command: ["/bin/sh"]
        args: ["-c", "echo '<h1>User Service</h1><h2>Environment: Development</h2><p>Partition: k8s-east</p><p>Namespace: development</p><p>This service calls ecommerce-api via Connect</p>' > /usr/share/nginx/html/index.html && nginx -g 'daemon off;'"]
---
apiVersion: v1
kind: Service
metadata:
  name: user-service-dev
  namespace: consul
spec:
  selector:
    app: user-service-dev
  ports:
  - port: 80
    targetPort: 80
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: notification-service-test
  namespace: consul
spec:
  replicas: 1
  selector:
    matchLabels:
      app: notification-service-test
  template:
    metadata:
      labels:
        app: notification-service-test
      annotations:
        consul.hashicorp.com/connect-inject: "true"
        consul.hashicorp.com/partition: "k8s-east"
        consul.hashicorp.com/namespace: "testing"
        consul.hashicorp.com/service-name: "notification-service"
        consul.hashicorp.com/service-tags: "version=test,environment=testing"
    spec:
      containers:
      - name: notification-service
        image: nginx:alpine
        ports:
        - containerPort: 80
        command: ["/bin/sh"]
        args: ["-c", "echo '<h1>Notification Service</h1><h2>Environment: Testing</h2><p>Partition: k8s-east</p><p>Namespace: testing</p>' > /usr/share/nginx/html/index.html && nginx -g 'daemon off;'"]
---
apiVersion: v1
kind: Service
metadata:
  name: notification-service-test
  namespace: consul
spec:
  selector:
    app: notification-service-test
  ports:
  - port: 80
    targetPort: 80
```

### West Cluster - Additional Services

```yaml
# west-additional-services.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: auth-service-dev
  namespace: consul
spec:
  replicas: 1
  selector:
    matchLabels:
      app: auth-service-dev
  template:
    metadata:
      labels:
        app: auth-service-dev
      annotations:
        consul.hashicorp.com/connect-inject: "true"
        consul.hashicorp.com/partition: "k8s-west"
        consul.hashicorp.com/namespace: "development"
        consul.hashicorp.com/service-name: "auth-service"
        consul.hashicorp.com/service-tags: "version=dev,environment=development"
        consul.hashicorp.com/connect-service-upstreams: "payment-service:9002"
    spec:
      containers:
      - name: auth-service
        image: nginx:alpine
        ports:
        - containerPort: 80
        command: ["/bin/sh"]
        args: ["-c", "echo '<h1>Auth Service</h1><h2>Environment: Development</h2><p>Partition: k8s-west</p><p>Namespace: development</p><p>This service calls payment-service via Connect</p>' > /usr/share/nginx/html/index.html && nginx -g 'daemon off;'"]
---
apiVersion: v1
kind: Service
metadata:
  name: auth-service-dev
  namespace: consul
spec:
  selector:
    app: auth-service-dev
  ports:
  - port: 80
    targetPort: 80
```

## Step 10: Create API Gateway Configurations with HTTPS

### East Cluster Gateway with HTTP Only

```yaml
# east-gateway.yaml
apiVersion: gateway.networking.k8s.io/v1beta1
kind: Gateway
metadata:
  name: api-gateway-east
  namespace: consul
spec:
  gatewayClassName: consul
  listeners:
  - protocol: HTTP
    port: 8080
    name: http
    allowedRoutes:
      namespaces:
        from: Same
---
apiVersion: gateway.networking.k8s.io/v1beta1
kind: HTTPRoute
metadata:
  name: east-dtap-routes
  namespace: consul
spec:
  parentRefs:
  - name: api-gateway-east
    sectionName: http
  rules:
  # Development environment routes
  - matches:
    - path:
        type: PathPrefix
        value: /dev/ecommerce
    backendRefs:
    - name: ecommerce-dev
      port: 80
  - matches:
    - path:
        type: PathPrefix
        value: /dev/users
    backendRefs:
    - name: user-service-dev
      port: 80
  # Testing environment routes
  - matches:
    - path:
        type: PathPrefix
        value: /test/ecommerce
    backendRefs:
    - name: ecommerce-test
      port: 80
  - matches:
    - path:
        type: PathPrefix
        value: /test/notifications
    backendRefs:
    - name: notification-service-test
      port: 80
  # Acceptance environment routes
  - matches:
    - path:
        type: PathPrefix
        value: /acc/ecommerce
    backendRefs:
    - name: ecommerce-acc
      port: 80
  # Health check route
  - matches:
    - path:
        type: PathPrefix
        value: /health
    backendRefs:
    - name: ecommerce-dev
      port: 80
```

### West Cluster Gateway with HTTP Only

```yaml
# west-gateway.yaml
apiVersion: gateway.networking.k8s.io/v1beta1
kind: Gateway
metadata:
  name: api-gateway-west
  namespace: consul
spec:
  gatewayClassName: consul
  listeners:
  - protocol: HTTP
    port: 8080
    name: http
    allowedRoutes:
      namespaces:
        from: Same
---
apiVersion: gateway.networking.k8s.io/v1beta1
kind: HTTPRoute
metadata:
  name: west-dtap-routes
  namespace: consul
spec:
  parentRefs:
  - name: api-gateway-west
    sectionName: http
  rules:
  # Development environment routes
  - matches:
    - path:
        type: PathPrefix
        value: /dev/payment
    backendRefs:
    - name: payment-dev
      port: 80
  - matches:
    - path:
        type: PathPrefix
        value: /dev/auth
    backendRefs:
    - name: auth-service-dev
      port: 80
  # Testing environment routes
  - matches:
    - path:
        type: PathPrefix
        value: /test/payment
    backendRefs:
    - name: payment-test
      port: 80
  # Production environment routes  
  - matches:
    - path:
        type: PathPrefix
        value: /prod/payment
    backendRefs:
    - name: payment-prod
      port: 80
  # Health check route
  - matches:
    - path:
        type: PathPrefix
        value: /health
    backendRefs:
    - name: payment-dev
      port: 80
```

## Step 11: Create Service Intentions for Service-to-Service Communication

Service intentions control which services can communicate with each other in the service mesh:

### East Cluster Intentions

```yaml
# east-intentions.yaml
apiVersion: consul.hashicorp.com/v1alpha1
kind: ServiceIntentions
metadata:
  name: user-to-ecommerce
  namespace: consul
spec:
  destination:
    name: ecommerce-api
    namespace: development
    partition: k8s-east
  sources:
    - name: user-service
      namespace: development
      partition: k8s-east
      action: allow
---
apiVersion: consul.hashicorp.com/v1alpha1
kind: ServiceIntentions
metadata:
  name: allow-gateway-to-services
  namespace: consul
spec:
  destination:
    name: "*"
    namespace: "*"
    partition: k8s-east
  sources:
    - name: api-gateway-east
      namespace: consul
      partition: k8s-east
      action: allow
```

### West Cluster Intentions

```yaml
# west-intentions.yaml
apiVersion: consul.hashicorp.com/v1alpha1
kind: ServiceIntentions
metadata:
  name: auth-to-payment
  namespace: consul
spec:
  destination:
    name: payment-service
    namespace: development
    partition: k8s-west
  sources:
    - name: auth-service
      namespace: development
      partition: k8s-west
      action: allow
---
apiVersion: consul.hashicorp.com/v1alpha1
kind: ServiceIntentions
metadata:
  name: allow-gateway-to-services-west
  namespace: consul
spec:
  destination:
    name: "*"
    namespace: "*"
    partition: k8s-west
  sources:
    - name: api-gateway-west
      namespace: consul
      partition: k8s-west
      action: allow
```

## Step 12: Deploy Everything

```bash
# Deploy additional services to East cluster
kubectl config use-context cluster-east
kubectl apply -f east-additional-services.yaml
kubectl apply -f east-gateway.yaml
kubectl apply -f east-intentions.yaml

# Deploy additional services to West cluster
kubectl config use-context cluster-west
kubectl apply -f west-additional-services.yaml
kubectl apply -f west-gateway.yaml
kubectl apply -f west-intentions.yaml
```

## Step 13: Test API Gateway Routing

### Wait for Services to be Ready

```bash
# East cluster
kubectl config use-context cluster-east
kubectl wait --for=condition=ready pod -l app=user-service-dev -n consul --timeout=300s
kubectl wait --for=condition=ready pod -l app=notification-service-test -n consul --timeout=300s

# West cluster
kubectl config use-context cluster-west
kubectl wait --for=condition=ready pod -l app=auth-service-dev -n consul --timeout=300s
```

### Port Forward and Test East Cluster

```bash
kubectl config use-context cluster-east

# Port forward HTTP only (no HTTPS since TLS is disabled)
kubectl port-forward -n consul svc/api-gateway-east 8080:8080 &

# Test HTTP routes
curl http://localhost:8080/dev/ecommerce
curl http://localhost:8080/dev/users  
curl http://localhost:8080/test/ecommerce
curl http://localhost:8080/test/notifications
curl http://localhost:8080/acc/ecommerce
curl http://localhost:8080/health
```

### Port Forward and Test West Cluster

```bash
kubectl config use-context cluster-west

# Port forward HTTP only
kubectl port-forward -n consul svc/api-gateway-west 8081:8080 &

# Test HTTP routes
curl http://localhost:8081/dev/payment
curl http://localhost:8081/dev/auth
curl http://localhost:8081/test/payment
curl http://localhost:8081/prod/payment
curl http://localhost:8081/health
```

## Step 14: Test Service-to-Service Communication

### Test Connect Communication in East Cluster

```bash
kubectl config use-context cluster-east

# Exec into user-service to test upstream connection to ecommerce-api
kubectl exec -it deployment/user-service-dev -n consul -c user-service -- sh

# Inside the container, test the upstream connection
# The ecommerce-api service is available at localhost:9001 via Connect sidecar
wget -qO- http://localhost:9001/ || echo "Connection test"
exit
```

### Test Connect Communication in West Cluster

```bash
kubectl config use-context cluster-west

# Exec into auth-service to test upstream connection to payment-service  
kubectl exec -it deployment/auth-service-dev -n consul -c auth-service -- sh

# Inside the container, test the upstream connection
# The payment-service is available at localhost:9002 via Connect sidecar
wget -qO- http://localhost:9002/ || echo "Connection test"
exit
```

### Verify Service Mesh Traffic in Consul UI

Access your Consul UI at `https://CONSUL_SERVER_IP:8500` and check:

1. **Service Topology**: View service-to-service connections
2. **Intentions**: Verify allow/deny rules are working
3. **Connect**: See sidecar proxy registrations
4. **Metrics**: View request rates and success rates

## Step 15: Advanced Routing Examples

### Add Canary Deployment Routing

```yaml
# canary-routing.yaml
apiVersion: gateway.networking.k8s.io/v1beta1
kind: HTTPRoute
metadata:
  name: canary-routing-east
  namespace: consul
spec:
  parentRefs:
  - name: api-gateway-east
    sectionName: http
  rules:
  # 90% traffic to stable version
  - matches:
    - path:
        type: PathPrefix
        value: /canary/ecommerce
    backendRefs:
    - name: ecommerce-acc
      port: 80
      weight: 90
    - name: ecommerce-test  
      port: 80
      weight: 10
  # Header-based routing for testing
  - matches:
    - path:
        type: PathPrefix
        value: /canary/ecommerce
      headers:
      - name: "x-canary"
        value: "true"
    backendRefs:
    - name: ecommerce-test
      port: 80
```

### Add Cross-Namespace Service Discovery

```yaml
# cross-namespace-routing.yaml  
apiVersion: gateway.networking.k8s.io/v1beta1
kind: HTTPRoute
metadata:
  name: cross-namespace-routes
  namespace: consul
spec:
  parentRefs:
  - name: api-gateway-east
    sectionName: http
  rules:
  # Route that spans multiple namespaces within the partition
  - matches:
    - path:
        type: PathPrefix
        value: /api/v1
    filters:
    - type: URLRewrite
      urlRewrite:
        path:
          type: ReplacePrefixMatch
          replacePrefixMatch: /
    backendRefs:
    - name: ecommerce-dev
      port: 80
  - matches:
    - path:
        type: PathPrefix
        value: /api/v2  
    filters:
    - type: URLRewrite
      urlRewrite:
        path:
          type: ReplacePrefixMatch
          replacePrefixMatch: /
    backendRefs:
    - name: ecommerce-test
      port: 80
```

Apply the advanced routing:

```bash
kubectl config use-context cluster-east
kubectl apply -f canary-routing.yaml
kubectl apply -f cross-namespace-routing.yaml

# Test canary routing
curl http://localhost:8080/canary/ecommerce
curl -H "x-canary: true" http://localhost:8080/canary/ecommerce

# Test versioned API routing
curl http://localhost:8080/api/v1
curl http://localhost:8080/api/v2
```

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