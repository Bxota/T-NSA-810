terraform {
  required_providers {
    proxmox = {
      source = "bpg/proxmox"
    }
  }
}

# Firewall/routeur de site basé sur pfSense.
# Cloné depuis le template pfSense (cf. scripts/bootstrap-proxmox.sh --with-pfsense).
# pfSense ne supporte PAS cloud-init : aucune initialisation ici, l'IP LAN et toute
# la configuration sont appliquées via le config.xml (rôle Ansible `pfsense`).

variable "vm_id" {}
variable "vm_name" {}
variable "target_node" {}
variable "clone" {
  type = number
} # PFSENSE_TEMPLATE_ID
variable "storage" {}
variable "cores" {
  default = 2
}
variable "memory" {
  default = 1024
}
variable "disk_size" {
  type    = number
  default = 8
}
variable "wan_bridge" {
  default = "vmbr0"
}
variable "lan_bridge" {}

resource "proxmox_virtual_environment_vm" "pfsense" {
  vm_id     = var.vm_id
  name      = var.vm_name
  node_name = var.target_node

  clone {
    vm_id = var.clone
    full  = true
  }

  # pfSense n'a pas le qemu-guest-agent activé par défaut.
  agent {
    enabled = false
  }


  operating_system {
    type = "other"
  }

  cpu {
    cores = var.cores
    type  = "host"
  }

  memory {
    dedicated = var.memory
  }

  disk {
    datastore_id = var.storage
    interface    = "scsi0"
    size         = var.disk_size
    iothread     = true
    file_format  = "raw"
  }

  scsi_hardware = "virtio-scsi-single"

  # NIC 0 : WAN (vmbr0, DHCP côté pfSense)
  network_device {
    model  = "virtio"
    bridge = var.wan_bridge
  }

  # NIC 1 : LAN (IP statique fixée par config.xml pfSense)
  network_device {
    model  = "virtio"
    bridge = var.lan_bridge
  }

  # Pas de bloc initialization : pfSense ignore cloud-init.

  lifecycle {
    ignore_changes = [network_device, disk]
  }
}

output "vm_name" { value = proxmox_virtual_environment_vm.pfsense.name }
