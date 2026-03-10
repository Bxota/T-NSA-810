terraform {
  required_providers {
    proxmox = {
      source = "bpg/proxmox"
    }
  }
}

variable "vm_id"       {}
variable "vm_name"     {}
variable "target_node" {}
variable "memory"      {}
variable "cores"       {}
variable "networks" {
  type = list(object({ bridge = string }))
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
  }

  memory {
    dedicated = var.memory
  }

  cdrom {
    enabled   = true
    file_id   = "local:iso/pfSense-CE-2.7.2-RELEASE-amd64.iso"
    interface = "ide2"
  }

  disk {
    datastore_id = "local-lvm"
    interface    = "scsi0"
    size         = 16
    file_format  = "raw"
  }

  dynamic "network_device" {
    for_each = var.networks
    content {
      model  = "virtio"
      bridge = network_device.value.bridge
    }
  }
}

output "vm_name" { value = proxmox_virtual_environment_vm.pfsense.name }
