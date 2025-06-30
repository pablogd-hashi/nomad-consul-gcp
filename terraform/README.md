# Terraform Infrastructure

This directory contains the Terraform configuration for deploying HashiStack (Consul + Nomad) on Google Cloud Platform.

## Quick Start

```bash
# Initialize Terraform
terraform init

# Plan the deployment
terraform plan

# Apply the infrastructure
terraform apply

# Get all tokens and access information
terraform output quick_start_commands
```

## Files

- `versions.tf` - Provider version constraints and Terraform Cloud configuration
- `main.tf` - Core infrastructure resources (VPC, compute instances, tokens)
- `variables.tf` - Input variables and their defaults
- `outputs.tf` - Output values including tokens and access URLs
- `packer.tf` - HCP Packer data sources for custom images
- `servers.tf` - Consul/Nomad server instances
- `clients.tf` - Nomad client instances  
- `load_balancer.tf` - GCP Load Balancer configuration
- `terraform.tfvars.example` - Example variable values

## Key Features

- **Automatic Token Generation** - All ACL tokens generated automatically
- **HCP Packer Integration** - Uses custom images from HCP Packer
- **Enterprise Features** - Consul/Nomad Enterprise with licensing
- **Service Discovery** - Full integration between Consul and Nomad
- **Load Balancing** - GCP HTTP Load Balancer with DNS
- **Monitoring Ready** - Prometheus/Grafana job definitions included

## Outputs

After deployment, use these commands to access your cluster:

```bash
# Get all tokens
terraform output -json all_tokens

# Access Consul UI
terraform output consul_ui_urls

# Access Nomad UI  
terraform output nomad_ui_urls

# SSH to instances
terraform output ssh_commands
```