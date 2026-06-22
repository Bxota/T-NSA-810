# ══════════════════════════════════════════════════════════════════════════════
# NetBox IPAM — Source de vérité réseau (seed)
# Chaque site est déclaré via le module réutilisable « site » (golden path).
# Ajouter un site = un nouveau bloc module (cf. docs/runbooks/add-site.md).
# IPs alignées sur terraform/locals.tf.
# ══════════════════════════════════════════════════════════════════════════════

module "site1" {
  source    = "./modules/site"
  site_name = "CIA Site 1"
  site_slug = "s1"
  prefix    = "10.1.0.0/24"
  ips = {
    "pfsense-s1"  = { address = var.ip_router_s1_lan, dns_name = "pfsense-s1.s1.cia" }
    netbox        = { address = var.ip_netbox, dns_name = "netbox.s1.cia" }
    elasticsearch = { address = var.ip_elasticsearch, dns_name = "elastic.s1.cia" }
  }
}

module "site2" {
  source    = "./modules/site"
  site_name = "CIA Site 2"
  site_slug = "s2"
  prefix    = "10.2.0.0/24"
  ips = {
    "pfsense-s2" = { address = var.ip_router_s2_lan, dns_name = "pfsense-s2.s2.cia" }
    bastion      = { address = var.ip_bastion, dns_name = "bastion.s2.cia" }
    webserver    = { address = var.ip_webserver, dns_name = "web.s2.cia" }
  }
}

# Préfixe VPN inter-sites (pas de site rattaché).
module "vpn" {
  source = "./modules/site"
  prefix = "10.8.0.0/24"
}

# ── Migration d'état (refacto resources → module) ─────────────────────────────
# Évite un destroy/create des objets NetBox existants.
moved {
  from = netbox_site.s1
  to   = module.site1.netbox_site.this[0]
}
moved {
  from = netbox_prefix.lan_s1
  to   = module.site1.netbox_prefix.this
}
moved {
  from = netbox_ip_address.router_s1_lan
  to   = module.site1.netbox_ip_address.this["pfsense-s1"]
}
moved {
  from = netbox_ip_address.netbox
  to   = module.site1.netbox_ip_address.this["netbox"]
}
moved {
  from = netbox_ip_address.elasticsearch
  to   = module.site1.netbox_ip_address.this["elasticsearch"]
}

moved {
  from = netbox_site.s2
  to   = module.site2.netbox_site.this[0]
}
moved {
  from = netbox_prefix.lan_s2
  to   = module.site2.netbox_prefix.this
}
moved {
  from = netbox_ip_address.router_s2_lan
  to   = module.site2.netbox_ip_address.this["pfsense-s2"]
}
moved {
  from = netbox_ip_address.bastion
  to   = module.site2.netbox_ip_address.this["bastion"]
}
moved {
  from = netbox_ip_address.webserver
  to   = module.site2.netbox_ip_address.this["webserver"]
}

moved {
  from = netbox_prefix.vpn
  to   = module.vpn.netbox_prefix.this
}
