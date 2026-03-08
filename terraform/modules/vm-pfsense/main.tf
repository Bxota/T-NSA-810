variable "vm_id" {}
variable "vm_name" {}
variable "target_node" {}
variable "memory" {}
variable "cores" {}
variable "networks" {
  type = list(object({ bridge = string }))
}

resource "proxmox_vm_qemu" "pfsense" {
  vmid        = var.vm_id
  name        = var.vm_name
  target_node = var.target_node
  iso         = "local:iso/pfSense-CE-2.7.2-RELEASE-amd64.iso"
  os_type     = "other"
  cores       = var.cores
  memory      = var.memory
  scsihw      = "virtio-scsi-pci"
  boot        = "cdn"

  disk {
    slot    = "scsi0"
    size    = "16G"
    type    = "scsi"
    storage = "local-lvm"
  }

  dynamic "network" {
    for_each = var.networks
    content {
      model  = "virtio"
      bridge = network.value.bridge
    }
  }
}