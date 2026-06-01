terraform {
  required_version = ">= 1.7"
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.73"
    }
  }
}

# Proxmox Site 1 — héberge les VMs du Site 1 (router-s1, netbox, elasticsearch)
provider "proxmox" {
  alias     = "pve_s1"
  endpoint  = var.proxmox_s1_api_url
  api_token = "${var.proxmox_s1_token_id}=${var.proxmox_s1_token_secret}"
  insecure  = true
}

# Proxmox Site 2 — héberge les VMs du Site 2 (router-s2, bastion, webserver)
provider "proxmox" {
  alias     = "pve_s2"
  endpoint  = var.proxmox_s2_api_url
  api_token = "${var.proxmox_s2_token_id}=${var.proxmox_s2_token_secret}"
  insecure  = true
}
