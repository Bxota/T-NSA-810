terraform {
  required_version = ">= 1.7"
  required_providers {
    netbox = {
      source  = "e-breuninger/netbox"
      version = "~> 3.10"
    }
  }
}

# Prérequis : terraform apply dans terraform/ + ansible (rôle netbox)
provider "netbox" {
  server_url = var.netbox_url
  api_token  = var.netbox_token
}
