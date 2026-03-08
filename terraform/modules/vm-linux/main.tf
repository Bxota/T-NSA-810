variable "vm_id" {}
variable "vm_name" {}
variable "target_node" {}
variable "clone" {}
variable "storage" {}
variable "cores" {}
variable "memory" {}
variable "disk_size" {}
variable "bridge" {}
variable "ip_config" {}
variable "ssh_key" {}
variable "vm_user" {}
variable "vm_password" { sensitive = true }

resource "proxmox_vm_qemu" "vm" {
  vmid        = var.vm_id
  name        = var.vm_name
  target_node = var.target_node
  clone       = var.clone
  full_clone  = true
  agent       = 1
  os_type     = "cloud-init"
  cores       = var.cores
  sockets     = 1
  memory      = var.memory

  disk {
    slot     = "scsi0"
    size     = var.disk_size
    type     = "scsi"
    storage  = var.storage
    iothread = 1
  }

  network {
    model  = "virtio"
    bridge = var.bridge
  }

  ipconfig0  = var.ip_config
  ciuser     = var.vm_user
  cipassword = var.vm_password
  sshkeys    = var.ssh_key

  lifecycle {
    ignore_changes = [network, disk]
  }
}

output "vm_name" { value = proxmox_vm_qemu.vm.name }