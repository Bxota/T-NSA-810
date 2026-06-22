# ══════════════════════════════════════════════════════════════════════════════
# SITE 1 — Proxmox S1
# Réseau LAN : 10.1.0.0/24 via vmbr1
# ══════════════════════════════════════════════════════════════════════════════

module "pfsense_s1" {
  source    = "./modules/vm-pfsense"
  providers = { proxmox = proxmox.pve_s1 }

  vm_id       = 400
  vm_name     = "cia-pfsense-s1"
  target_node = var.proxmox_s1_node
  clone       = var.s1_pfsense_template_id
  storage     = var.storage
  cores       = 2
  memory      = 1024
  disk_size   = 8
  wan_bridge  = "vmbr0" # WAN → internet
  lan_bridge  = "vmbr1" # LAN S1 10.1.0.0/24
}

module "netbox" {
  source    = "./modules/vm-linux"
  providers = { proxmox = proxmox.pve_s1 }

  vm_id       = 401
  vm_name     = "cia-netbox"
  target_node = var.proxmox_s1_node
  clone       = var.s1_template_id
  storage     = var.storage
  cores       = 2
  memory      = 8192
  disk_size   = 15
  bridge      = "vmbr1"
  ip_address  = local.ip.netbox
  gateway     = local.gw.s1
  ssh_key     = var.ssh_public_key
  vm_user     = var.vm_user
  vm_password = var.vm_password
}

module "elasticsearch" {
  source    = "./modules/vm-linux"
  providers = { proxmox = proxmox.pve_s1 }

  vm_id       = 402
  vm_name     = "cia-elastic"
  target_node = var.proxmox_s1_node
  clone       = var.s1_template_id
  storage     = var.storage
  cores       = 4
  memory      = 16384
  disk_size   = 15
  bridge      = "vmbr1"
  ip_address  = local.ip.elasticsearch
  gateway     = local.gw.s1
  ssh_key     = var.ssh_public_key
  vm_user     = var.vm_user
  vm_password = var.vm_password
}

# ══════════════════════════════════════════════════════════════════════════════
# SITE 2 — Proxmox S2
# Réseau LAN : 10.2.0.0/24 via vmbr2
# ══════════════════════════════════════════════════════════════════════════════

module "pfsense_s2" {
  source    = "./modules/vm-pfsense"
  providers = { proxmox = proxmox.pve_s2 }

  vm_id       = 403
  vm_name     = "cia-pfsense-s2"
  target_node = var.proxmox_s2_node
  clone       = var.s2_pfsense_template_id
  storage     = var.storage
  cores       = 2
  memory      = 1024
  disk_size   = 8
  wan_bridge  = "vmbr0" # WAN → internet
  lan_bridge  = "vmbr2" # LAN S2 10.2.0.0/24
}

module "bastion" {
  source    = "./modules/vm-linux"
  providers = { proxmox = proxmox.pve_s2 }

  vm_id       = 404
  vm_name     = "cia-bastion"
  target_node = var.proxmox_s2_node
  clone       = var.s2_template_id
  storage     = var.storage
  cores       = 1
  memory      = 4096
  disk_size   = 10
  bridge      = "vmbr2"
  ip_address  = local.ip.bastion
  gateway     = local.gw.s2
  ssh_key     = var.ssh_public_key
  vm_user     = var.vm_user
  vm_password = var.vm_password
}

module "webserver" {
  source    = "./modules/vm-linux"
  providers = { proxmox = proxmox.pve_s2 }

  vm_id       = 405
  vm_name     = "cia-web"
  target_node = var.proxmox_s2_node
  clone       = var.s2_template_id
  storage     = var.storage
  cores       = 2
  memory      = 4096
  disk_size   = 15
  bridge      = "vmbr2"
  ip_address  = local.ip.webserver
  gateway     = local.gw.s2
  ssh_key     = var.ssh_public_key
  vm_user     = var.vm_user
  vm_password = var.vm_password
}
