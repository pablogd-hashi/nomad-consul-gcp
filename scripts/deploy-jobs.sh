#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
CONSUL_ADDR="${CONSUL_HTTP_ADDR:-http://localhost:8500}"
NOMAD_ADDR="${NOMAD_ADDR:-http://localhost:4646}"
JOBS_DIR="$(dirname "$0")/../jobs"

echo -e "${BLUE}=== HashiStack Job Deployment Script ===${NC}"
echo

# Function to check if service is healthy
check_service() {
    local service_name=$1
    local port=$2
    local endpoint=${3:-"/"}
    
    echo -e "${YELLOW}Checking $service_name health...${NC}"
    
    for i in {1..30}; do
        if curl -s -f "http://localhost:$port$endpoint" >/dev/null 2>&1; then
            echo -e "${GREEN}✓ $service_name is healthy${NC}"
            return 0
        fi
        echo -n "."
        sleep 2
    done
    
    echo -e "${RED}✗ $service_name health check failed${NC}"
    return 1
}

# Function to wait for job to be running
wait_for_job() {
    local job_name=$1
    echo -e "${YELLOW}Waiting for job '$job_name' to be running...${NC}"
    
    for i in {1..60}; do
        local status=$(nomad job status -short "$job_name" 2>/dev/null | grep Status | awk '{print $3}' || echo "unknown")
        
        if [ "$status" = "running" ]; then
            echo -e "${GREEN}✓ Job '$job_name' is running${NC}"
            return 0
        elif [ "$status" = "dead" ]; then
            echo -e "${RED}✗ Job '$job_name' failed to start${NC}"
            nomad job status "$job_name"
            return 1
        fi
        
        echo -n "."
        sleep 2
    done
    
    echo -e "${RED}✗ Job '$job_name' failed to reach running state${NC}"
    return 1
}

# Function to deploy a job
deploy_job() {
    local job_file=$1
    local job_name=$(basename "$job_file" .nomad.hcl)
    
    echo -e "${BLUE}Deploying job: $job_name${NC}"
    
    if [ ! -f "$job_file" ]; then
        echo -e "${RED}✗ Job file not found: $job_file${NC}"
        return 1
    fi
    
    # Validate job file
    if ! nomad job validate "$job_file"; then
        echo -e "${RED}✗ Job validation failed for $job_name${NC}"
        return 1
    fi
    
    # Plan job
    echo -e "${YELLOW}Planning job $job_name...${NC}"
    nomad job plan "$job_file"
    
    # Deploy job
    echo -e "${YELLOW}Running job $job_name...${NC}"
    nomad job run "$job_file"
    
    # Wait for job to be running
    wait_for_job "$job_name"
}

# Check prerequisites
echo -e "${BLUE}Checking prerequisites...${NC}"

# Check if Consul is available
if ! curl -s "$CONSUL_ADDR/v1/status/leader" >/dev/null; then
    echo -e "${RED}✗ Consul is not available at $CONSUL_ADDR${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Consul is available${NC}"

# Check if Nomad is available
if ! curl -s "$NOMAD_ADDR/v1/status/leader" >/dev/null; then
    echo -e "${RED}✗ Nomad is not available at $NOMAD_ADDR${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Nomad is available${NC}"

# Check if jobs directory exists
if [ ! -d "$JOBS_DIR" ]; then
    echo -e "${RED}✗ Jobs directory not found: $JOBS_DIR${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Jobs directory found${NC}"

echo

# Create host volumes for Prometheus and Grafana data
echo -e "${BLUE}Creating host volumes...${NC}"

# Create directories on client nodes (you might need to SSH to each client)
echo -e "${YELLOW}Note: You may need to manually create these directories on client nodes:${NC}"
echo "  sudo mkdir -p /opt/nomad/host_volumes/prometheus_data"
echo "  sudo mkdir -p /opt/nomad/host_volumes/grafana_data"
echo "  sudo chown -R nobody:nogroup /opt/nomad/host_volumes/"
echo

# Deploy jobs in order
echo -e "${BLUE}Starting job deployment...${NC}"
echo

# 1. Deploy Traefik first (API Gateway)
echo -e "${BLUE}=== Step 1: Deploying Traefik (API Gateway) ===${NC}"
deploy_job "$JOBS_DIR/traefik.nomad.hcl"
sleep 10

# Check if Traefik is healthy
check_service "Traefik" "8080" "/ping"
echo

# 2. Deploy Prometheus
echo -e "${BLUE}=== Step 2: Deploying Prometheus ===${NC}"
deploy_job "$JOBS_DIR/prometheus.nomad.hcl"
sleep 10

# Check if Prometheus is healthy
check_service "Prometheus" "9090" "/-/healthy"
echo

# 3. Deploy Grafana
echo -e "${BLUE}=== Step 3: Deploying Grafana ===${NC}"
deploy_job "$JOBS_DIR/grafana.nomad.hcl"
sleep 10

# Check if Grafana is healthy
check_service "Grafana" "3000" "/api/health"
echo

# 4. Deploy Terramino
echo -e "${BLUE}=== Step 4: Deploying Terramino ===${NC}"
deploy_job "$JOBS_DIR/terramino.nomad.hcl"
sleep 10
echo

# 5. Optional: Deploy Consul Connect Proxy
read -p "Deploy Consul Connect Proxy? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${BLUE}=== Step 5: Deploying Consul Connect Proxy ===${NC}"
    deploy_job "$JOBS_DIR/consul-connect-proxy.nomad.hcl"
    echo
fi

# Show final status
echo -e "${BLUE}=== Deployment Summary ===${NC}"
echo
nomad job status
echo

# Show service discovery
echo -e "${BLUE}=== Service Discovery ===${NC}"
echo
consul catalog services
echo

# Show application URLs
echo -e "${BLUE}=== Application URLs ===${NC}"
echo -e "${GREEN}Traefik Dashboard:${NC} http://localhost:8080"
echo -e "${GREEN}Consul UI:${NC} http://localhost:8500"
echo -e "${GREEN}Nomad UI:${NC} http://localhost:4646"
echo -e "${GREEN}Prometheus:${NC} http://localhost:9090"
echo -e "${GREEN}Grafana:${NC} http://localhost:3000 (admin/admin)"
echo

# Get load balancer IP from Terraform output
if command -v terraform >/dev/null 2>&1; then
    LB_IP=$(terraform output -raw load_balancer_ip 2>/dev/null || echo "not-available")
    if [ "$LB_IP" != "not-available" ]; then
        echo -e "${BLUE}=== Load Balancer URLs ===${NC}"
        echo -e "${GREEN}Terramino:${NC} http://terramino.hashistack.local (or http://$LB_IP with Host header)"
        echo -e "${GREEN}Grafana:${NC} http://grafana.hashistack.local (or http://$LB_IP with Host header)"
        echo -e "${GREEN}Prometheus:${NC} http://prometheus.hashistack.local (or http://$LB_IP with Host header)"
        echo
        echo -e "${YELLOW}Add these to your /etc/hosts file:${NC}"
        echo "$LB_IP terramino.hashistack.local"
        echo "$LB_IP grafana.hashistack.local"
        echo "$LB_IP prometheus.hashistack.local"
    fi
fi

echo
echo -e "${GREEN}=== Deployment Complete! ===${NC}"
echo -e "${YELLOW}Tip: Use 'nomad alloc logs <alloc-id>' to view application logs${NC}"
echo -e "${YELLOW}Tip: Use 'consul catalog services' to see all registered services${NC}"