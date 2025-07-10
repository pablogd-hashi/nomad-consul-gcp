# Consul Admin Partitions Demo

Complete demonstration of **Consul Enterprise Admin Partitions** using Google Kubernetes Engine (GKE).

## What You Get

🏗️ **4 GKE Clusters**:
- 2 Consul server clusters (us-east1, us-west1)  
- 2 Admin partition clients (us-east4, us-west2)

🔐 **Enterprise Features**:
- Admin partitions: `k8s-east` and `k8s-west`
- Service mesh with cross-partition communication
- DTAP environments: development, testing, acceptance, production

## Prerequisites

### 1. Required Tools
```bash
# Install these first:
gcloud CLI
terraform
helm  
kubectl
task (go-task.github.io/task)
```

### 2. GCP Setup
```bash
# Authenticate and set project
gcloud auth login
gcloud config set project YOUR_PROJECT_ID

# Enable required APIs
gcloud services enable container.googleapis.com
gcloud services enable compute.googleapis.com
```

### 3. Required Variables
```bash
# Set your Consul Enterprise license
export CONSUL_LICENSE="02MV4UU43BK5HGYYTOJZWFQMTMN..."
```

## Quick Start

### Deploy Everything
```bash
cd consul/admin-partitions
task deploy
```

### Check Status  
```bash
task status
```

### Get Consul URLs
```bash
task info
```

### Deploy Demo Apps
```bash
task deploy-apps
```

### Clean Up
```bash
task destroy
```

## Folder Structure

```
admin-partitions/
├── README.md           # This guide
├── Taskfile.yml        # Simple automation
├── terraform/          # Infrastructure as code
│   ├── server-east/    # Consul servers (us-east1)
│   ├── server-west/    # Consul servers (us-west1)
│   ├── client-east/    # k8s-east partition (us-east4)
│   └── client-west/    # k8s-west partition (us-west2)
├── helm/               # Consul configurations
│   └── [same structure as terraform]
└── apps/               # Demo applications
    └── fake-service/   # Frontend/backend services
```

## What Gets Created

- **4 GKE clusters** in different US regions
- **Consul Enterprise 1.21.2-ent** with admin partitions
- **Load balancers** for Consul UI access
- **Service mesh** between partitions  
- **DTAP namespaces** in each partition
- **Demo applications** showing cross-partition communication

## Admin Partitions Demo

1. **Isolation**: Each partition runs independent workloads
2. **Communication**: Services can talk across partitions via mesh
3. **Multi-tenancy**: DTAP environments within each partition
4. **Security**: ACLs and policies per partition