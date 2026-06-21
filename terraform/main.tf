# ═══════════════════════════════════════════════════════════════
# CIA — Infrastructure as Code
# main.tf — Bridges · Images · Template · VMs
# ═══════════════════════════════════════════════════════════════

# ── BRIDGES ─────────────────────────────────────────────────────

resource "proxmox_network_linux_bridge" "vmbr1" {
  node_name = var.TARGET_NODE
  name      = "vmbr1"
  address   = "10.1.0.254/24"
  comment   = "Site 1 — LAN isolé 10.1.0.0/24"
}

resource "proxmox_network_linux_bridge" "vmbr2" {
  node_name = var.TARGET_NODE
  name      = "vmbr2"
  address   = "10.2.0.254/24"
  comment   = "Site 2 — LAN isolé 10.2.0.0/24"
}

# ── IMAGES ──────────────────────────────────────────────────────
resource "proxmox_download_file" "ubuntu_cloud_image" {
  node_name    = var.TARGET_NODE
  content_type = "iso"
  datastore_id = var.STORAGE
  file_name    = "noble-server-cloudimg-amd64.img"
  url          = "https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img"
  overwrite    = false
}

resource "proxmox_download_file" "pfsense_iso" {
  node_name               = var.TARGET_NODE
  content_type            = "iso"
  datastore_id            = var.STORAGE
  file_name               = "pfSense-CE-2.7.2-RELEASE-amd64.iso"
  url                     = "https://atxfiles.netgate.com/mirror/downloads/pfSense-CE-2.7.2-RELEASE-amd64.iso.gz"
  decompression_algorithm = "gz"
  overwrite               = false
}

# ── TEMPLATE UBUNTU 24.04 ───────────────────────────────────────
resource "proxmox_virtual_environment_vm" "ubuntu_template" {
  vm_id     = var.TEMPLATE_ID
  name      = "ubuntu-2404-template"
  node_name = var.TARGET_NODE
  template  = true

  cpu {
    cores = 2
    type  = "host"
  }

  memory {
    dedicated = 2048
  }

  disk {
    datastore_id = var.STORAGE
    file_id      = proxmox_download_file.ubuntu_cloud_image.id
    interface    = "scsi0"
    iothread     = true
    file_format  = "raw"
    size         = 20
  }

  scsi_hardware = "virtio-scsi-single"

  network_device {
    model  = "virtio"
    bridge = "vmbr0"
  }

  operating_system {
    type = "l26"
  }

  agent {
    enabled = true
  }

  serial_device {}

  depends_on = [
    proxmox_download_file.ubuntu_cloud_image,
  ]
}

# ═══════════════════════════════════════════════════════════════
# SITE 1 — ON-PREM
# ═══════════════════════════════════════════════════════════════

module "pfsense_s1" {
  source      = "./modules/vm-pfsense"
  vm_id       = 400
  vm_name     = "cia-pf-s1"
  target_node = var.TARGET_NODE
  storage     = var.STORAGE
  cores       = 2
  memory      = 2048
  iso_file_id = proxmox_download_file.pfsense_iso.id
  networks = [
    { bridge = "vmbr0" },
    { bridge = "vmbr1" },
    { bridge = "vmbr1" },
    { bridge = "vmbr1" },
  ]
  depends_on = [
    proxmox_network_linux_bridge.vmbr1,
    proxmox_download_file.pfsense_iso,
  ]
}

module "netbox" {
  source      = "./modules/vm-linux"
  vm_id       = 401
  vm_name     = "cia-netbox"
  target_node = var.TARGET_NODE
  clone       = var.TEMPLATE_ID
  storage     = var.STORAGE
  cores       = 2
  memory      = 4096
  disk_size   = 40
  bridge      = "vmbr1"
  ip_address  = "10.1.0.10/24"
  gateway     = "10.1.0.254"
  ssh_key     = var.SSH_PUBLIC_KEY
  vm_user     = var.VM_USER
  vm_password = var.VM_PASSWORD
  depends_on  = [
    proxmox_virtual_environment_vm.ubuntu_template,
    proxmox_network_linux_bridge.vmbr1,
  ]
}

module "elasticsearch" {
  source      = "./modules/vm-linux"
  vm_id       = 402
  vm_name     = "cia-elastic"
  target_node = var.TARGET_NODE
  clone       = var.TEMPLATE_ID
  storage     = var.STORAGE
  cores       = 4
  memory      = 8192
  disk_size   = 80
  bridge      = "vmbr1"
  ip_address  = "10.1.0.20/24"
  gateway     = "10.1.0.254"
  ssh_key     = var.SSH_PUBLIC_KEY
  vm_user     = var.VM_USER
  vm_password = var.VM_PASSWORD
  depends_on  = [
    proxmox_virtual_environment_vm.ubuntu_template,
    proxmox_network_linux_bridge.vmbr1,
  ]
}

# ═══════════════════════════════════════════════════════════════
# SITE 2 — REMOTE
# ═══════════════════════════════════════════════════════════════

module "pfsense_s2" {
  source      = "./modules/vm-pfsense"
  vm_id       = 403
  vm_name     = "cia-pf-s2"
  target_node = var.TARGET_NODE
  storage     = var.STORAGE
  cores       = 2
  memory      = 2048
  iso_file_id = proxmox_download_file.pfsense_iso.id
  networks = [
    { bridge = "vmbr0" },
    { bridge = "vmbr2" },
    { bridge = "vmbr2" },
    { bridge = "vmbr2" },
  ]
  depends_on = [
    proxmox_network_linux_bridge.vmbr2,
    proxmox_download_file.pfsense_iso,
  ]
}

module "bastion" {
  source      = "./modules/vm-linux"
  vm_id       = 404
  vm_name     = "cia-bastion"
  target_node = var.TARGET_NODE
  clone       = var.TEMPLATE_ID
  storage     = var.STORAGE
  cores       = 1
  memory      = 1024
  disk_size   = 20
  bridge      = "vmbr2"
  ip_address  = "10.2.0.5/24"
  gateway     = "10.2.0.254"
  ssh_key     = var.SSH_PUBLIC_KEY
  vm_user     = var.VM_USER
  vm_password = var.VM_PASSWORD
  depends_on  = [
    proxmox_virtual_environment_vm.ubuntu_template,
    proxmox_network_linux_bridge.vmbr2,
  ]
}

module "webserver" {
  source      = "./modules/vm-linux"
  vm_id       = 405
  vm_name     = "cia-web"
  target_node = var.TARGET_NODE
  clone       = var.TEMPLATE_ID
  storage     = var.STORAGE
  cores       = 2
  memory      = 2048
  disk_size   = 30
  bridge      = "vmbr2"
  ip_address  = "10.2.0.30/24"
  gateway     = "10.2.0.254"
  ssh_key     = var.SSH_PUBLIC_KEY
  vm_user     = var.VM_USER
  vm_password = var.VM_PASSWORD
  depends_on  = [
    proxmox_virtual_environment_vm.ubuntu_template,
    proxmox_network_linux_bridge.vmbr2,
  ]
}
