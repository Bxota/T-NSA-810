terraform {
  required_providers {
    proxmox = {
      source = "bpg/proxmox"
    }
  }
}

# Module pfSense — mode CLONE.
# Clone un template pfSense (installe + SSH active) au lieu d'installer depuis l'ISO.
# La config par site (LAN, OpenVPN, regles, DNS) vient du config.xml importe ensuite
# (config-s1.xml / config-s2.xml) — voir pfsense/README.md.

variable "vm_id" {}
variable "vm_name" {}
variable "target_node" {}
variable "template_id" {
  description = "VMID du template pfSense a cloner (9100 sur pve2, 9101 sur pve3)"
  type        = number
}
variable "cores" { default = 2 }
variable "memory" { default = 2048 }
variable "networks" {
  description = "Liste ordonnee des bridges : [0]=WAN, [1]=LAN"
  type        = list(object({ bridge = string }))
}

resource "proxmox_virtual_environment_vm" "pfsense" {
  vm_id         = var.vm_id
  name          = var.vm_name
  node_name     = var.target_node
  scsi_hardware = "virtio-scsi-pci"

  clone {
    vm_id = var.template_id
    full  = true
  }

  operating_system {
    type = "other"
  }

  cpu {
    cores = var.cores
    type  = "host" # expose la virtualisation (nested)
  }

  memory {
    dedicated = var.memory
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
    ignore_changes = [network_device, disk]
  }
}

output "vm_name" { value = proxmox_virtual_environment_vm.pfsense.name }
