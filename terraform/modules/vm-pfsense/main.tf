terraform {
  required_providers {
    proxmox = {
      source = "bpg/proxmox"
    }
  }
}

# Module pfSense — repris de la branche main, adapte pour le cluster a deux noeuds.
# Cree une VM pfSense (install depuis ISO) avec N cartes reseau (WAN puis LAN).
# La config interne (interfaces, regles, OpenVPN, DNS, NAT) se fait DANS pfSense
# (console/GUI ou restauration d'un config.xml) — voir docs/pfSense-config.md.

variable "vm_id" {}
variable "vm_name" {}
variable "target_node" {}
variable "cores" { default = 2 }
variable "memory" { default = 2048 }
variable "disk_size" { default = 16 }
variable "storage" { default = "local-lvm" }
variable "pfsense_iso" {
  description = "Volid de l'ISO pfSense sur le stockage 'local' du noeud"
  default     = "local:iso/pfSense-CE-2.7.2-RELEASE-amd64.iso"
}
variable "networks" {
  description = "Liste ordonnee des bridges : [0]=WAN, [1]=LAN"
  type        = list(object({ bridge = string }))
}

resource "proxmox_virtual_environment_vm" "pfsense" {
  vm_id         = var.vm_id
  name          = var.vm_name
  node_name     = var.target_node
  scsi_hardware = "virtio-scsi-pci"
  boot_order    = ["ide2", "scsi0"]

  operating_system {
    type = "other"
  }

  cpu {
    cores = var.cores
    type  = "host" # expose les instructions de virtualisation (nested)
  }

  memory {
    dedicated = var.memory
  }

  cdrom {
    enabled   = true
    file_id   = var.pfsense_iso
    interface = "ide2"
  }

  disk {
    datastore_id = var.storage
    interface    = "scsi0"
    size         = var.disk_size
    file_format  = "raw"
  }

  dynamic "network_device" {
    for_each = var.networks
    content {
      model  = "virtio"
      bridge = network_device.value.bridge
    }
  }

  # pfSense gere ses interfaces lui-meme : on ignore les diffs reseau/disque
  lifecycle {
    ignore_changes = [network_device, disk, cdrom]
  }
}

output "vm_name" { value = proxmox_virtual_environment_vm.pfsense.name }
