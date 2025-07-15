# ✅ Working Consul GKE Admin Partitions Deployment

## Architecture

- **GKE West1** (`k8s-west1` partition) → connects to **DC1** (gcp-dc1)
- **GKE Southwest** (`k8s-southwest` partition) → connects to **DC2** (gcp-dc2)

## Critical Success Factors (What Fixed the Issues)

### 1. **Correct Datacenter Mapping**
- GKE West1 → DC1 (not DC2 as initially attempted)
- GKE Southwest → DC2 (not DC1 as initially attempted)

### 2. **Proper CA Certificate Configuration**
- **MUST** use CA certificates from the correct datacenter
- **MUST** include both `caCert` AND `caKey` in Helm values
- **MUST** create both `consul-ca-cert` and `consul-ca-key` secrets

### 3. **Simplified External Servers Configuration**
- Remove explicit port configurations (`httpsPort`, `grpcPort`)
- Remove extra flags (`useSystemRoots`, `skipServerWatch`)
- Use simple host list with `tlsServerName`

## Working Deployment Commands

### **Step 1: Create Admin Partitions on Consul Servers**

```bash
# DC1 - Create k8s-west1 partition
task infra:ssh-dc1-server
consul partition create -name="k8s-west1" -description="GKE West1 Cluster"
consul namespace create -name="development" -partition="k8s-west1"
consul namespace create -name="testing" -partition="k8s-west1"
consul namespace create -name="acceptance" -partition="k8s-west1"
consul partition list
exit

# DC2 - Create k8s-southwest partition
task infra:ssh-dc2-server
consul partition create -name="k8s-southwest" -description="GKE Southwest Cluster"
consul namespace create -name="development" -partition="k8s-southwest"
consul namespace create -name="testing" -partition="k8s-southwest"
consul namespace create -name="production" -partition="k8s-southwest"
consul partition list
exit
```

### **Step 2: Deploy GKE West1 (connects to DC1)**

```bash
# Set license and authenticate
export CONSUL_ENT_LICENSE="your-consul-enterprise-license-here"
kubectl config use-context gke_hc-1031dcc8d7c24bfdbb4c08979b0_europe-west1_gke-cluster-gke
kubectl create namespace consul --dry-run=client -o yaml | kubectl apply -f -

# Get DC1 bootstrap token
cd clusters/dc1/terraform
BOOTSTRAP_TOKEN=$(terraform output -json auth_tokens | jq -r '.consul_token')
echo "Bootstrap token: ${BOOTSTRAP_TOKEN:0:8}..."
cd ../../gke-europe-west1/manifests

# Create ALL required secrets (CRITICAL: both cert AND key)
kubectl create secret generic consul-ent-license \
  --namespace=consul \
  --from-literal=key="$CONSUL_ENT_LICENSE" \
  --dry-run=client -o yaml | kubectl apply -f -

kubectl create secret generic consul-ca-cert \
  --namespace=consul \
  --from-file=tls.crt="../../dc1/terraform/consul-agent-ca.pem" \
  --dry-run=client -o yaml | kubectl apply -f -

kubectl create secret generic consul-ca-key \
  --namespace=consul \
  --from-file=tls.key="../../dc1/terraform/consul-agent-ca-key.pem" \
  --dry-run=client -o yaml | kubectl apply -f -

kubectl create secret generic consul-bootstrap-token \
  --namespace=consul \
  --from-literal=token="$BOOTSTRAP_TOKEN" \
  --dry-run=client -o yaml | kubectl apply -f -

kubectl create secret generic consul-partitions-acl-token \
  --namespace=consul \
  --from-literal=token="$BOOTSTRAP_TOKEN" \
  --dry-run=client -o yaml | kubectl apply -f -

kubectl create secret generic consul-dns-token \
  --namespace=consul \
  --from-literal=token="$BOOTSTRAP_TOKEN" \
  --dry-run=client -o yaml | kubectl apply -f -

# Verify all secrets exist
kubectl get secrets -n consul

# Deploy Consul
cd ../helm
helm repo add hashicorp https://helm.releases.hashicorp.com
helm repo update
helm install consul hashicorp/consul --namespace consul --values values.yaml
```

### **Step 3: Deploy GKE Southwest (connects to DC2)**

```bash
# Set license and authenticate
export CONSUL_ENT_LICENSE="your-consul-enterprise-license-here"
kubectl config use-context gke_hc-1031dcc8d7c24bfdbb4c08979b0_europe-southwest1_gke-southwest-gke
kubectl create namespace consul --dry-run=client -o yaml | kubectl apply -f -

# Get DC2 bootstrap token
cd clusters/dc2/terraform
BOOTSTRAP_TOKEN=$(terraform output -json auth_tokens | jq -r '.consul_token')
echo "Bootstrap token: ${BOOTSTRAP_TOKEN:0:8}..."
cd ../../gke-southwest/manifests

# Create ALL required secrets with DC2 certificates
kubectl create secret generic consul-ent-license \
  --namespace=consul \
  --from-literal=key="$CONSUL_ENT_LICENSE" \
  --dry-run=client -o yaml | kubectl apply -f -

kubectl create secret generic consul-ca-cert \
  --namespace=consul \
  --from-file=tls.crt="../../dc2/terraform/consul-agent-ca.pem" \
  --dry-run=client -o yaml | kubectl apply -f -

kubectl create secret generic consul-ca-key \
  --namespace=consul \
  --from-file=tls.key="../../dc2/terraform/consul-agent-ca-key.pem" \
  --dry-run=client -o yaml | kubectl apply -f -

kubectl create secret generic consul-bootstrap-token \
  --namespace=consul \
  --from-literal=token="$BOOTSTRAP_TOKEN" \
  --dry-run=client -o yaml | kubectl apply -f -

kubectl create secret generic consul-partitions-acl-token \
  --namespace=consul \
  --from-literal=token="$BOOTSTRAP_TOKEN" \
  --dry-run=client -o yaml | kubectl apply -f -

kubectl create secret generic consul-dns-token \
  --namespace=consul \
  --from-literal=token="$BOOTSTRAP_TOKEN" \
  --dry-run=client -o yaml | kubectl apply -f -

# Verify all secrets exist
kubectl get secrets -n consul

# Deploy Consul
cd ../helm
helm repo add hashicorp https://helm.releases.hashicorp.com
helm repo update
helm install consul hashicorp/consul --namespace consul --values values.yaml
```

## Working Helm Configuration Key Points

### **Critical TLS Configuration**
```yaml
# MUST include both caCert AND caKey
tls:
  enabled: true
  enableAutoEncrypt: true
  verify: false
  caCert:
    secretName: consul-ca-cert
    secretKey: tls.crt
  caKey:                    # THIS IS REQUIRED!
    secretName: consul-ca-key
    secretKey: tls.key
```

### **Simplified External Servers**
```yaml
# DON'T specify ports - let Consul use defaults
externalServers:
  enabled: true
  hosts:
    - "server-ip-1"
    - "server-ip-2" 
    - "server-ip-3"
  tlsServerName: server.gcp-dc1.consul  # Match datacenter
  k8sAuthMethodHost: "https://gke-api-endpoint"
```

## Verification Commands

```bash
# Check GKE West1 connection
kubectl config use-context gke_hc-1031dcc8d7c24bfdbb4c08979b0_europe-west1_gke-cluster-gke
kubectl get pods -n consul
kubectl logs -n consul -l app=consul --tail=20

# Check GKE Southwest connection
kubectl config use-context gke_hc-1031dcc8d7c24bfdbb4c08979b0_europe-southwest1_gke-southwest-gke
kubectl get pods -n consul
kubectl logs -n consul -l app=consul --tail=20

# Verify partitions on servers
task infra:ssh-dc1-server
consul partition list
consul catalog services -partition k8s-west1

task infra:ssh-dc2-server  
consul partition list
consul catalog services -partition k8s-southwest
```

## Success Indicators

Look for these log messages indicating successful connection:
```
[INFO] consul-server-connection-manager: connected to Consul server
[INFO] Admin Partition already exists: name=k8s-west1
[INFO] consul-server-connection-manager: stopping
```

## Common Issues Fixed

1. **TLS Handshake Errors** → Fixed by using correct datacenter CA certificates
2. **Missing caKey Secret** → Fixed by creating both consul-ca-cert AND consul-ca-key
3. **Wrong Datacenter Mapping** → Fixed by connecting GKE West1 to DC1 (not DC2)
4. **Complex External Servers Config** → Fixed by simplifying to basic host list
5. **Port Configuration Issues** → Fixed by removing explicit port settings

This configuration is now proven to work for Consul Enterprise admin partitions on GKE!