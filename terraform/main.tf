# ══════════════════════════════════════════════════════════════════════════════
# Déploiement MULTI-SITES — entièrement piloté par var.sites (sites.auto.tfvars).
# Ajouter un site = ajouter une entrée dans la map. AUCUN nouveau module/bloc.
# ══════════════════════════════════════════════════════════════════════════════

# ── pfSense : un firewall/routeur par site ────────────────────────────────────
module "pfsense" {
  source   = "./modules/vm-pfsense"
  for_each = var.sites

  vm_id       = each.value.pfsense_vmid
  vm_name     = "cia-pf-${each.key}"
  target_node = each.value.node
  template_id = each.value.pfsense_template
  cores       = 2
  memory      = 3072
  networks = [
    { bridge = "vmbr0" },               # WAN
    { bridge = each.value.lan_bridge }, # LAN du site
  ]
}

# ── VMs applicatives : toutes les VMs de tous les sites, en une boucle ────────
module "vm" {
  source   = "./modules/vm-linux"
  for_each = local.vms

  vm_id       = each.value.vmid
  vm_name     = "cia-${each.value.name}"
  target_node = each.value.node
  clone       = each.value.template
  storage     = var.storage
  cores       = each.value.cores
  memory      = each.value.memory
  disk_size   = each.value.disk
  bridge      = each.value.bridge
  ip_address  = each.value.ip
  gateway     = each.value.gateway
  ssh_key     = var.ssh_public_key
  vm_user     = var.vm_user
  vm_password = var.vm_password
}
