# ══════════════════════════════════════════════════════════════════════════════
# Aplatissement des VMs de tous les sites en une seule map "site-service",
# pour pouvoir les déployer avec un for_each unique dans main.tf.
# Ex: { "s1-netbox" = {...}, "s1-elastic" = {...}, "s2-bastion" = {...}, ... }
# ══════════════════════════════════════════════════════════════════════════════
locals {
  vms = merge([
    for site_key, site in var.sites : {
      for vm_key, vm in site.vms :
      "${site_key}-${vm_key}" => {
        name     = vm_key
        node     = site.node
        bridge   = site.lan_bridge
        gateway  = site.gateway
        template = site.ubuntu_template
        vmid     = vm.vmid
        cores    = vm.cores
        memory   = vm.memory
        disk     = vm.disk
        ip       = vm.ip
      }
    }
  ]...)
}
