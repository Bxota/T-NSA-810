terraform {
  required_providers {
    proxmox = { source = "bpg/proxmox" }
  }
}

variable "vm_id"       {}
variable "vm_name"     {}
variable "target_node" {}
variable "storage"     {}
variable "memory"      {}
variable "cores"       {}
variable "iso_file_id" {}
variable "networks" {
  type = list(object({ bridge = string }))
}

resource "proxmox_virtual_environment_vm" "pfsense" {
  vm_id     = var.vm_id
  name      = var.vm_name
  node_name = var.target_node

  operating_system {
    type = "other"
  }

  scsi_hardware = "virtio-scsi-pci"
  boot_order    = ["ide2", "scsi0"]

  cpu {
    cores = var.cores
    type  = "host"
  }

  memory {
    dedicated = var.memory
  }

  cdrom {
    file_id   = var.iso_file_id
    interface = "ide2"
  }

  disk {
    datastore_id = var.storage
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
