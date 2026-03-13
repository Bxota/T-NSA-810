resource "proxmox_virtual_environment_vm" "netbox_bootstrap" {
  name      = var.netbox_name
  node_name = var.target_node
  vm_id     = var.netbox_vm_id

  description = "Temporary NetBox Bootstrap VM - lifecycle test"
  on_boot     = true

  clone {
    vm_id = var.template_vm_id
    full  = true
  }

  cpu {
    cores = 2
  }

  memory {
    dedicated = 4096
  }

  disk {
    datastore_id = var.storage_name
    interface    = "scsi0"
    size         = 20
  }

  network_device {
    bridge = var.site1_bridge
  }

  initialization {
    ip_config {
      ipv4 {
        address = var.netbox_ip
        gateway = var.gateway
      }
    }
  }

  agent {
    enabled = false
  }

  stop_on_destroy = true

}