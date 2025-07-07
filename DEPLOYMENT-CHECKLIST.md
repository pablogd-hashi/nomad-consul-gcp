# 🚀 RELIABLE DEPLOYMENT CHECKLIST

## ✅ PRE-DEPLOYMENT VALIDATION COMPLETED

All configuration files have been thoroughly validated and one critical issue has been fixed.

### 🔧 **Fixed Issues:**
- **DC1 Prometheus Configuration**: Updated to use dynamic IPs instead of localhost
- **DNS References**: All terraform configurations properly reference existing DNS records
- **Port Configuration**: Both clusters use exactly 5 ports (GCP limit compliant)
- **Template Files**: All server and client templates have correct UI and telemetry configs

## 📋 **DEPLOYMENT ORDER**

### **1. Infrastructure Deployment**
```bash
# Deploy DC1 Infrastructure
cd clusters/dc1/terraform
terraform init
terraform plan
terraform apply

# Deploy DC2 Infrastructure  
cd ../dc2/terraform
terraform init
terraform plan
terraform apply
```

### **2. Get Access Information**
```bash
# DC1 Access URLs and IPs
cd clusters/dc1/terraform
terraform output load_balancers
terraform output hashistack_urls
terraform output monitoring_urls

# DC2 Access URLs and IPs
cd clusters/dc2/terraform  
terraform output load_balancers
terraform output hashistack_urls
terraform output monitoring_urls
```

### **3. Application Deployment**

#### **DC1 Applications:**
```bash
cd clusters/dc1
# Set environment
eval "$(cd terraform && terraform output -raw environment_setup | jq -r .bash_export)"

# Deploy monitoring stack
nomad job run jobs/monitoring/traefik.hcl
nomad job run jobs/monitoring/prometheus.hcl  
nomad job run jobs/monitoring/grafana.hcl
nomad job run jobs/monitoring/loki.hcl

# Deploy demo applications
nomad job run jobs/terramino.hcl
```

#### **DC2 Applications:**
```bash
cd clusters/dc2
# Set environment  
eval "$(cd terraform && terraform output -raw environment_setup | jq -r .bash_export)"

# Deploy monitoring stack
nomad job run jobs/monitoring/traefik.hcl
nomad job run jobs/monitoring/prometheus.hcl
nomad job run jobs/monitoring/grafana.hcl  
nomad job run jobs/monitoring/loki.hcl

# Deploy demo applications
nomad job run jobs/terramino.hcl
```

### **4. API Gateway Deployment**
```bash
# Deploy API Gateway and demo services
nomad job run nomad-apps/api-gw.nomad/api-gw.nomad.hcl
nomad job run nomad-apps/demo-fake-service/backend.nomad.hcl
nomad job run nomad-apps/demo-fake-service/frontend.nomad.hcl

# Configure Consul API Gateway (SSH to server node)
consul config write consul/peering/configs/api-gateway/listener.hcl
consul config write consul/peering/configs/api-gateway/httproute.hcl
```

## 🌐 **ACCESS POINTS**

### **DC1 (europe-southwest1)**
```bash
# Get LB IPs
terraform output load_balancers

# Direct access URLs:
# Consul UI: http://<global_lb_ip>:8500
# Nomad UI: http://<global_lb_ip>:4646  
# Grafana: http://<clients_lb_ip>:3000 (admin/admin)
# Prometheus: http://<clients_lb_ip>:9090
# Traefik: http://<clients_lb_ip>:8080
# API Gateway: http://<clients_lb_ip>:8081
# Loki: http://<clients_lb_ip>:3100
```

### **DC2 (europe-west1)**
```bash
# Get LB IPs  
terraform output load_balancers

# Direct access URLs:
# Consul UI: http://<global_lb_ip>:8500
# Nomad UI: http://<global_lb_ip>:4646
# Grafana: http://<clients_lb_ip>:3000 (admin/admin) 
# Prometheus: http://<clients_lb_ip>:9090
# Traefik: http://<clients_lb_ip>:8080
# API Gateway: http://<clients_lb_ip>:8081
# Loki: http://<clients_lb_ip>:3100
```

## 🔍 **VERIFICATION STEPS**

### **1. Infrastructure Health**
```bash
# Check cluster members
consul members
nomad server members
nomad node status

# Check job status
nomad job status
```

### **2. Service Health**
```bash
# Check service discovery
consul catalog services
consul catalog nodes

# Check application logs  
nomad alloc logs <allocation-id>
```

### **3. Monitoring Stack**
- ✅ **Prometheus**: Should show Nomad metrics (fixed configuration)
- ✅ **Grafana**: Should have both Prometheus and Loki datasources + Nomad dashboards OoTB
- ✅ **Loki**: Should collect systemd and allocation logs
- ✅ **Consul UI**: Should show metrics integration

## ⚠️ **COMMON ISSUES & SOLUTIONS**

### **Issue: nomad ui -authenticate fails**
**Solution**: Use load balancer IP instead of DNS
```bash
export NOMAD_ADDR="http://<global_lb_ip>:4646"
nomad ui -authenticate
```

### **Issue: Prometheus not collecting Nomad metrics**
**Solution**: Already fixed - DC1 now uses dynamic IPs like DC2

### **Issue: DNS resolution fails**
**Solution**: Use direct IP access - all outputs now provide load balancer IPs

## 🎯 **SUCCESS CRITERIA**

- [ ] Infrastructure deploys without errors
- [ ] All services register in Consul  
- [ ] Prometheus collects Nomad and Consul metrics
- [ ] Grafana shows dashboards with both metrics and logs
- [ ] API Gateway routes to front-service
- [ ] Load balancer IPs accessible on all ports
- [ ] Consul UI shows metrics integration
- [ ] Loki collects logs from systemd and applications

## 📝 **CONFIGURATION SUMMARY**

### **✅ Validated Configurations:**
- **Port Configuration**: 5 ports max (GCP compliant)
- **DNS Records**: Only created where needed, properly referenced
- **SSL Certificates**: Match existing DNS records only
- **Template Files**: Include UI config and telemetry  
- **Nomad Jobs**: Fixed Prometheus, added Loki, Grafana integration
- **Load Balancer**: Exposes all required application ports

### **🔧 Recent Fixes:**
- Fixed DC1 Prometheus to use dynamic IPs 
- Removed Traefik tags from DC1 Prometheus
- Added Consul UI metrics and dashboard integration
- Added telemetry to Nomad clients for metric collection
- Created comprehensive Loki logging stack

**Configuration is now DEPLOYMENT-READY! 🚀**