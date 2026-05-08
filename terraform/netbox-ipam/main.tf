# ══════════════════════════════════════════════════════════════════════════════
# NetBox IPAM — Source de vérité réseau (runtime)
# Appliqué après : terraform apply (terraform/) + ansible (rôle netbox)
# IPs définies dans terraform/locals.tf, reflétées ici via variables.
# ══════════════════════════════════════════════════════════════════════════════

# ── Sites ─────────────────────────────────────────────────────────────────────

resource "netbox_site" "s1" {
  name = "CIA Site 1"
  slug = "s1"
}

resource "netbox_site" "s2" {
  name = "CIA Site 2"
  slug = "s2"
}

# ── Préfixes ──────────────────────────────────────────────────────────────────

resource "netbox_prefix" "lan_s1" {
  prefix  = "10.1.0.0/24"
  site_id = netbox_site.s1.id
  status  = "active"
}

resource "netbox_prefix" "lan_s2" {
  prefix  = "10.2.0.0/24"
  site_id = netbox_site.s2.id
  status  = "active"
}

resource "netbox_prefix" "vpn" {
  prefix = "10.8.0.0/24"
  status = "active"
}

# ── Adresses IP ───────────────────────────────────────────────────────────────

resource "netbox_ip_address" "router_s1_lan" {
  ip_address = var.ip_router_s1_lan
  status     = "active"
  dns_name   = "router-s1.s1.cia"
}

resource "netbox_ip_address" "netbox" {
  ip_address = var.ip_netbox
  status     = "active"
  dns_name   = "netbox.s1.cia"
}

resource "netbox_ip_address" "elasticsearch" {
  ip_address = var.ip_elasticsearch
  status     = "active"
  dns_name   = "elastic.s1.cia"
}

resource "netbox_ip_address" "router_s2_lan" {
  ip_address = var.ip_router_s2_lan
  status     = "active"
  dns_name   = "router-s2.s2.cia"
}

resource "netbox_ip_address" "bastion" {
  ip_address = var.ip_bastion
  status     = "active"
  dns_name   = "bastion.s2.cia"
}

resource "netbox_ip_address" "webserver" {
  ip_address = var.ip_webserver
  status     = "active"
  dns_name   = "web.s2.cia"
}
