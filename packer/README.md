# Packer Image Builds

This directory contains Packer configurations for building HashiStack images on Google Cloud Platform.

## Quick Start

```bash
# Build server image
cd builds/
packer build -var-file=../variables/common.pkrvars.hcl hashistack-server.pkr.hcl

# Build client image  
packer build -var-file=../variables/common.pkrvars.hcl hashistack-client.pkr.hcl
```

## Directory Structure

- `builds/` - Packer build configurations (.pkr.hcl files)
- `scripts/` - Provisioning and configuration scripts
- `configs/` - Configuration templates for Consul and Nomad
- `variables/` - Variable files for different environments

## Images Built

### HashiStack Server (`hashistack-server.pkr.hcl`)
- Ubuntu 22.04 LTS base
- Consul Enterprise (server mode)
- Nomad Enterprise (server mode)
- Docker runtime
- Monitoring tools

### HashiStack Client (`hashistack-client.pkr.hcl`)  
- Ubuntu 22.04 LTS base
- Consul Enterprise (client mode)
- Nomad Enterprise (client mode)
- Docker runtime with privileged containers
- Host volumes for persistent storage

## Required Environment Variables

```bash
export HCP_CLIENT_ID="your-hcp-client-id"
export HCP_CLIENT_SECRET="your-hcp-client-secret"
```

## Variable Files

- `common.pkrvars.hcl` - Shared variables across environments
- `dev.pkrvars.hcl` - Development environment overrides
- `prod.pkrvars.hcl` - Production environment overrides

## HCP Packer Integration

Images are automatically published to HCP Packer registry with:
- **Bucket names**: `hashistack-server`, `hashistack-client`
- **Channels**: `latest`, `stable` 
- **Metadata**: Consul/Nomad versions, build timestamps