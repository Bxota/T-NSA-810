# ── SITE 1 ─────────────────────────────────────────

module "pfsense_s1" {
  source      = "./modules/vm-pfsense"
  vm_id       = 400
  vm_name     = "cia-pf-s1"
  target_node = var.target_node
  cores       = 2
  memory      = 2048
  networks = [
    { bridge = "vmbr0" },   # WAN
    { bridge = "vmbr1" },   # LAN S1 10.1.0.0/24
  ]
}

module "netbox" {
  source      = "./modules/vm-linux"
  vm_id       = 401
  vm_name     = "cia-netbox"
  target_node = var.target_node
  clone       = var.template_id
  storage     = var.storage
  cores       = 2
  memory      = 4096
  disk_size   = 40
  bridge      = "vmbr1"
  ip_address  = "10.1.0.10/24"
  gateway     = "10.1.0.254"
  ssh_key     = var.ssh_public_key
  vm_user     = var.vm_user
  vm_password = var.vm_password
}

module "elasticsearch" {
  source      = "./modules/vm-linux"
  vm_id       = 402
  vm_name     = "cia-elastic"
  target_node = var.target_node
  clone       = var.template_id
  storage     = var.storage
  cores       = 4
  memory      = 8192
  disk_size   = 80
  bridge      = "vmbr1"
  ip_address  = "10.1.0.20/24"
  gateway     = "10.1.0.254"
  ssh_key     = var.ssh_public_key
  vm_user     = var.vm_user
  vm_password = var.vm_password
}

# ── SITE 2 ─────────────────────────────────────────

module "pfsense_s2" {
  source      = "./modules/vm-pfsense"
  vm_id       = 403
  vm_name     = "cia-pf-s2"
  target_node = var.target_node
  cores       = 2
  memory      = 2048
  networks = [
    { bridge = "vmbr0" },   # WAN
    { bridge = "vmbr2" },   # LAN S2 10.2.0.0/24
  ]
}

module "bastion" {
  source      = "./modules/vm-linux"
  vm_id       = 404
  vm_name     = "cia-bastion"
  target_node = var.target_node
  clone       = var.template_id
  storage     = var.storage
  cores       = 1
  memory      = 1024
  disk_size   = 20
  bridge      = "vmbr2"
  ip_address  = "10.2.0.5/24"
  gateway     = "10.2.0.254"
  ssh_key     = var.ssh_public_key
  vm_user     = var.vm_user
  vm_password = var.vm_password
}

module "webserver" {
  source      = "./modules/vm-linux"
  vm_id       = 405
  vm_name     = "cia-web"
  target_node = var.target_node
  clone       = var.template_id
  storage     = var.storage
  cores       = 2
  memory      = 2048
  disk_size   = 30
  bridge      = "vmbr2"
  ip_address  = "10.2.0.30/24"
  gateway     = "10.2.0.254"
  ssh_key     = var.ssh_public_key
  vm_user     = var.vm_user
  vm_password = var.vm_password
}
