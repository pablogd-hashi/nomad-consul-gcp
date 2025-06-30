terraform {
  cloud {
    organization = "pablogd-hcp-test"
    workspaces {
      name = "hashistack-terramino-nomad-consul"
    }
  }
  
  required_version = ">= 1.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
    consul = {
      source  = "hashicorp/consul"
      version = "~> 2.20"
    }
    nomad = {
      source  = "hashicorp/nomad"
      version = "~> 2.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.4"
    }
    hcp = {
      source  = "hashicorp/hcp"
      version = "~> 0.82"
    }
  }
}