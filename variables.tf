variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "region" {
  description = "GCP Region"
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "GCP Zone"
  type        = string
  default     = "us-central1-a"
}

variable "subnet_cidr" {
  description = "CIDR block for the subnet"
  type        = string
  default     = "10.0.0.0/16"
}

variable "machine_type_server" {
  description = "Machine type for Nomad/Consul servers"
  type        = string
  default     = "e2-standard-2"
}

variable "machine_type_client" {
  description = "Machine type for Nomad clients"
  type        = string
  default     = "e2-standard-4"
}

variable "consul_license" {
  description = "Consul Enterprise License"
  type        = string
  sensitive   = true
}

variable "nomad_license" {
  description = "Nomad Enterprise License"
  type        = string
  sensitive   = true
}

variable "consul_version" {
  description = "Consul version to install"
  type        = string
  default     = "1.17.0+ent"
}

variable "nomad_version" {
  description = "Nomad version to install"
  type        = string
  default     = "1.7.2+ent"
}

variable "consul_datacenter" {
  description = "Consul datacenter name"
  type        = string
  default     = "dc1"
}

variable "nomad_datacenter" {
  description = "Nomad datacenter name"
  type        = string
  default     = "dc1"
}

variable "domain_name" {
  description = "Domain name for the applications"
  type        = string
  default     = "hashistack.local"
}

variable "enable_acls" {
  description = "Enable ACLs for Consul and Nomad"
  type        = bool
  default     = true
}

variable "enable_tls" {
  description = "Enable TLS for Consul and Nomad"
  type        = bool
  default     = true
}

variable "consul_log_level" {
  description = "Consul log level"
  type        = string
  default     = "INFO"
}

variable "nomad_log_level" {
  description = "Nomad log level"
  type        = string
  default     = "INFO"
}

variable "ssh_public_key" {
  description = "SSH public key for instance access"
  type        = string
}