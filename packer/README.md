# HashiStack Packer Images

This directory contains Packer configurations to build custom GCP images with HashiCorp Consul and Nomad pre-installed.

## Structure

```
packer/
├── builds/                     # Packer configuration files
│   ├── hashistack-server.pkr.hcl   # Server image (Consul + Nomad servers)
│   └── hashistack-client.pkr.hcl   # Client image (Nomad workers)
├── scripts/                    # Installation scripts
│   ├── consul_prep.sh              # Consul installation script
│   └── nomad_prep.sh               # Nomad installation script
├── variables/                  # Build variables
│   └── common.pkrvars.hcl          # Common variables for builds
├── manifest-server.json       # Generated: Server build manifest
├── manifest-client.json       # Generated: Client build manifest
└── README.md                   # This file
```

## Quick Start

1. **Configure variables**:
   ```bash
   # Edit packer/variables/common.pkrvars.hcl
   gcp_project = "your-gcp-project-id"
   ```

2. **Build images**:
   ```bash
   # From project root:
   task build-server   # Build server image
   task build-client   # Build client image
   ```

## What Gets Installed

### Base Image
- **Debian 12** (debian-cloud/debian-12)

### HashiCorp Software
- **Consul Enterprise** (version in common.pkrvars.hcl)
- **Nomad Enterprise** (version in common.pkrvars.hcl)
- **Docker** + Docker Compose Plugin
- **CNI Plugins** for networking

### System Setup
- Dedicated system users (`consul`, `nomad`)
- Proper directory structure (`/opt/consul`, `/opt/nomad`, `/etc/consul.d`, `/etc/nomad.d`)
- TLS certificates and encryption keys (Consul)
- Systemd service files

## Manual Build Commands

If you prefer manual commands:

```bash
cd packer/builds

# Validate configurations
packer validate -var-file=../variables/common.pkrvars.hcl hashistack-server.pkr.hcl
packer validate -var-file=../variables/common.pkrvars.hcl hashistack-client.pkr.hcl

# Build images
packer build -var-file=../variables/common.pkrvars.hcl hashistack-server.pkr.hcl
packer build -var-file=../variables/common.pkrvars.hcl hashistack-client.pkr.hcl
```

## Image Output

- **Server Image**: `consul-nomad-server-TIMESTAMP`
- **Client Image**: `consul-nomad-client-TIMESTAMP`
- **Image Family**: `consul-nomad-server` / `consul-nomad-client`
- **Manifests**: Generated in this directory after builds

## Notes

- Images are built in the GCP project specified in `common.pkrvars.hcl`
- Build process takes ~10-15 minutes per image
- Images include all HashiCorp software but no configuration (added at runtime)
- Use these images with the Terraform configurations in `../terraform/`