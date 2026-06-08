terraform {
  required_version = ">= 1.7"
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.73"
    }
  }
}

provider "proxmox" {
  endpoint  = var.PROXMOX_API_URL
  api_token = "${var.PROXMOX_TOKEN_ID}=${var.PROXMOX_TOKEN_SECRET}"
  insecure  = true

  ssh {
    agent       = false
    username    = "root"
    private_key = var.SSH_PRIVATE_KEY
  }
}
