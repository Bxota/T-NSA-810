# ══════════════════════════════════════════════════════════════════════════════
# SITE 1 — Proxmox S1 (noeud var.proxmox_s1_node)
# Reseau LAN : 10.1.0.0/24 via vmbr1  ·  Firewall : pfSense (LAN 10.1.0.1)
# ══════════════════════════════════════════════════════════════════════════════

module "pfsense_s1" {
  source    = "./modules/vm-pfsense"
  providers = { proxmox = proxmox.pve_s1 }

  vm_id       = 400
  vm_name     = "cia-pf-s1"
  target_node = var.proxmox_s1_node
  cores       = 2
  memory      = 2048
  storage     = var.storage
  pfsense_iso = var.pfsense_iso
  networks = [
    { bridge = "vmbr0" }, # WAN  -> reseau du parent / internet
    { bridge = "vmbr1" }, # LAN  -> 10.1.0.0/24 (gateway pfSense = 10.1.0.1)
  ]
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
  memory      = 4096
  disk_size   = 40
  bridge      = "vmbr1"
  ip_address  = local.ip.netbox
  gateway     = local.gw.s1 # 10.1.0.1 = pfSense S1
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
  memory      = 8192
  disk_size   = 80
  bridge      = "vmbr1"
  ip_address  = local.ip.elasticsearch
  gateway     = local.gw.s1
  ssh_key     = var.ssh_public_key
  vm_user     = var.vm_user
  vm_password = var.vm_password
}

# ══════════════════════════════════════════════════════════════════════════════
# SITE 2 — Proxmox S2 (noeud var.proxmox_s2_node)
# Reseau LAN : 10.2.0.0/24 via vmbr2  ·  Firewall : pfSense (LAN 10.2.0.1)
# ══════════════════════════════════════════════════════════════════════════════

module "pfsense_s2" {
  source    = "./modules/vm-pfsense"
  providers = { proxmox = proxmox.pve_s2 }

  vm_id       = 403
  vm_name     = "cia-pf-s2"
  target_node = var.proxmox_s2_node
  cores       = 2
  memory      = 2048
  storage     = var.storage
  pfsense_iso = var.pfsense_iso
  networks = [
    { bridge = "vmbr0" }, # WAN
    { bridge = "vmbr2" }, # LAN -> 10.2.0.0/24 (gateway pfSense = 10.2.0.1)
  ]
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
  memory      = 2048
  disk_size   = 20
  bridge      = "vmbr2"
  ip_address  = local.ip.bastion
  gateway     = local.gw.s2 # 10.2.0.1 = pfSense S2
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
  memory      = 2048
  disk_size   = 30
  bridge      = "vmbr2"
  ip_address  = local.ip.webserver
  gateway     = local.gw.s2
  ssh_key     = var.ssh_public_key
  vm_user     = var.vm_user
  vm_password = var.vm_password
}
