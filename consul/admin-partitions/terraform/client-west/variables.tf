variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "consul_version" {
  description = "Consul Enterprise version"
  type        = string
  default     = "1.21.2-ent"
}

variable "consul_license" {
  description = "Consul Enterprise license"
  type        = string
  sensitive   = true
}

variable "consul_server_ip" {
  description = "Consul server external IP address"
  type        = string
}

variable "consul_ca_cert" {
  description = "Consul CA certificate"
  type        = string
  sensitive   = true
}

variable "consul_bootstrap_token" {
  description = "Consul bootstrap token for admin partitions"
  type        = string
  sensitive   = true
}

variable "service_account_email" {
  description = "Service account email for GKE nodes"
  type        = string
  default     = null
}