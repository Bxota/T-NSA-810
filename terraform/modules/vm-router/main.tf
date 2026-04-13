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
variable "wan_bridge"  { default = "vmbr0" }
variable "lan_bridge"  {}
variable "lan_ip"      {}   # ex: "10.1.0.1/24"
variable "ssh_key"     {}
variable "vm_user"     {}
variable "vm_password" { sensitive = true }

resource "proxmox_virtual_environment_vm" "router" {
  vm_id     = var.vm_id
  name      = var.vm_name
  node_name = var.target_node

  clone {
    vm_id = var.clone
    full  = true
  }

  agent {
    enabled = false
  }

  operating_system {
    type = "l26"
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

  # NIC 0 : WAN (DHCP, accès internet)
  network_device {
    model  = "virtio"
    bridge = var.wan_bridge
  }

  # NIC 1 : LAN (IP statique via cloud-init)
  network_device {
    model  = "virtio"
    bridge = var.lan_bridge
  }

  initialization {
    ip_config {
      # NIC 0 (WAN) : DHCP
      ipv4 {
        address = "dhcp"
      }
    }
    ip_config {
      # NIC 1 (LAN) : IP statique, pas de gateway (c'est lui le gateway)
      ipv4 {
        address = var.lan_ip
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

output "vm_name" { value = proxmox_virtual_environment_vm.router.name }
