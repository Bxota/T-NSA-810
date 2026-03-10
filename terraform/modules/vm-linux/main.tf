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
variable "clone"       { type = number }
variable "storage"     {}
variable "cores"       {}
variable "memory"      {}
variable "disk_size"   { type = number }
variable "bridge"      {}
variable "ip_address"  {}
variable "gateway"     {}
variable "ssh_key"     {}
variable "vm_user"     {}
variable "vm_password" { sensitive = true }

resource "proxmox_virtual_environment_vm" "vm" {
  vm_id     = var.vm_id
  name      = var.vm_name
  node_name = var.target_node

  clone {
    vm_id = var.clone
    full  = true
  }

  agent {
    enabled = true
  }

  operating_system {
    type = "l26"
  }

  cpu {
    cores = var.cores
  }

  memory {
    dedicated = var.memory
  }

  disk {
    datastore_id = var.storage
    interface    = "scsi0"
    size         = var.disk_size
    iothread     = true
  }

  network_device {
    model  = "virtio"
    bridge = var.bridge
  }

  initialization {
    ip_config {
      ipv4 {
        address = var.ip_address
        gateway = var.gateway
      }
    }
    user_account {
      username = var.vm_user
      password = var.vm_password
      keys     = [var.ssh_key]
    }
  }

  lifecycle {
    ignore_changes = [network_device, disk]
  }
}

output "vm_name" { value = proxmox_virtual_environment_vm.vm.name }
