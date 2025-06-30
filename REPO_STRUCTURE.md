# Repository Structure - HashiStack GCP Deployment

## 📁 Proposed Directory Layout

```
nomad-consul-terramino/
├── README.md                          # Main project documentation
├── CLAUDE.md                          # AI assistant instructions
├── .gitignore                         # Git ignore patterns
├── .github/                           # GitHub workflows and templates
│   └── workflows/
│       ├── terraform-plan.yml         # PR validation
│       └── terraform-apply.yml        # Deployment automation
│
├── terraform/                         # Infrastructure as Code
│   ├── main.tf                        # Core infrastructure
│   ├── variables.tf                   # Input variables
│   ├── outputs.tf                     # Output values
│   ├── versions.tf                    # Provider versions
│   ├── terraform.tfvars.example       # Example variables
│   ├── modules/                       # Reusable modules
│   │   ├── consul-cluster/             # Consul-specific resources
│   │   ├── nomad-cluster/              # Nomad-specific resources
│   │   └── networking/                 # VPC, firewall, etc.
│   └── environments/                  # Environment-specific configs
│       ├── dev/
│       ├── staging/
│       └── prod/
│
├── packer/                            # Image building
│   ├── README.md                      # Packer-specific docs
│   ├── builds/                        # Build configurations
│   │   ├── consul-server.pkr.hcl      # Consul server image
│   │   ├── nomad-server.pkr.hcl       # Nomad server image
│   │   └── nomad-client.pkr.hcl       # Nomad client image
│   ├── scripts/                       # Provisioning scripts
│   │   ├── install-consul.sh          # Consul installation
│   │   ├── install-nomad.sh           # Nomad installation
│   │   ├── configure-server.sh        # Server configuration
│   │   └── configure-client.sh        # Client configuration
│   ├── configs/                       # Configuration templates
│   │   ├── consul/
│   │   │   ├── server.hcl.tpl         # Consul server config template
│   │   │   └── client.hcl.tpl         # Consul client config template
│   │   └── nomad/
│   │       ├── server.hcl.tpl         # Nomad server config template
│   │       └── client.hcl.tpl         # Nomad client config template
│   └── variables/                     # Variable files
│       ├── common.pkrvars.hcl         # Shared variables
│       ├── dev.pkrvars.hcl           # Dev environment
│       └── prod.pkrvars.hcl          # Production environment
│
├── nomad-jobs/                        # Application deployments
│   ├── README.md                      # Job deployment docs
│   ├── core/                          # Core infrastructure jobs
│   │   ├── traefik.nomad.hcl         # Load balancer
│   │   ├── prometheus.nomad.hcl       # Monitoring
│   │   └── grafana.nomad.hcl         # Dashboards
│   ├── applications/                  # Application jobs
│   │   └── terramino.nomad.hcl       # Demo application
│   └── templates/                     # Job templates
│       └── webapp.nomad.hcl.tpl      # Generic web app template
│
├── scripts/                           # Automation scripts
│   ├── deploy.sh                      # Full deployment script
│   ├── get-tokens.sh                  # Token retrieval
│   ├── bootstrap-acls.sh              # ACL setup
│   └── cleanup.sh                     # Environment cleanup
│
├── docs/                              # Documentation
│   ├── architecture.md               # System architecture
│   ├── deployment.md                 # Deployment guide
│   ├── troubleshooting.md            # Common issues
│   └── examples/                     # Usage examples
│       ├── basic-webapp/
│       └── microservices/
│
└── tests/                            # Testing
    ├── integration/                   # Integration tests
    ├── terraform/                     # Terraform tests
    └── packer/                       # Packer validation
```

## 🎯 Benefits of This Structure

### **1. Clear Separation of Concerns**
- **terraform/** - Infrastructure provisioning
- **packer/** - Image building  
- **nomad-jobs/** - Application deployment
- **scripts/** - Automation utilities

### **2. Environment Management**
- Environment-specific configurations
- Consistent structure across dev/staging/prod
- Easy to add new environments

### **3. Team Collaboration**
- Clear ownership boundaries
- Reusable modules and templates
- Comprehensive documentation

### **4. CI/CD Ready**
- GitHub Actions workflows
- Automated testing structure
- Standardized scripts

### **5. Scalability**
- Modular Terraform design
- Template-based configurations
- Extensible job definitions

## 🚀 Migration Plan

1. **Phase 1**: Restructure core files (terraform/, packer/)
2. **Phase 2**: Organize jobs and scripts
3. **Phase 3**: Add documentation and tests
4. **Phase 4**: Implement CI/CD workflows