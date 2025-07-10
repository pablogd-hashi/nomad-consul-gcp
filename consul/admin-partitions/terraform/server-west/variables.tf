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

variable "service_account_email" {
  description = "Service account email for GKE nodes"
  type        = string
  default     = null
}