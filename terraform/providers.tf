terraform {
  required_version = ">= 1.7"
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.73"
    }
  }
}

# Un SEUL provider pour tout le cluster (pve2 + pve3 + futurs noeuds).
# Le noeud cible de chaque ressource est choisi par `node_name`
# (= var.sites[*].node). C'est ce qui permet le for_each multi-sites :
# plus besoin d'un provider aliasé par site.
provider "proxmox" {
  endpoint  = var.proxmox_api_url
  api_token = "${var.proxmox_token_id}=${var.proxmox_token_secret}"
  insecure  = true
}
