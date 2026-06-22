# ══════════════════════════════════════════════════════════════════════════════
# Module « site » — Golden path IPAM NetBox
# Déclare un site + son préfixe + ses adresses IP en une seule invocation.
# Réutilisable tel quel pour onboarder un nouveau site (cf. runbooks/add-site.md).
# ══════════════════════════════════════════════════════════════════════════════

terraform {
  required_providers {
    netbox = {
      source = "e-breuninger/netbox"
    }
  }
}

variable "site_name" {
  type        = string
  description = "Nom lisible du site (ex. « CIA Site 3 »). Vide = pas de site (ex. préfixe VPN)."
  default     = ""
}

variable "site_slug" {
  type        = string
  description = "Slug du site (ex. « s3 »). Vide = pas de site."
  default     = ""
}

variable "prefix" {
  type        = string
  description = "Préfixe réseau du site (ex. « 10.3.0.0/24 »)."
}

variable "ips" {
  type = map(object({
    address  = string # CIDR, ex. « 10.3.0.10/24 »
    dns_name = string
  }))
  description = "Adresses IP du site, indexées par une clé stable (nom d'hôte)."
  default     = {}
}

locals {
  has_site = var.site_slug != ""
}

resource "netbox_site" "this" {
  count = local.has_site ? 1 : 0
  name  = var.site_name
  slug  = var.site_slug
}

resource "netbox_prefix" "this" {
  prefix  = var.prefix
  status  = "active"
  site_id = local.has_site ? netbox_site.this[0].id : null
}

resource "netbox_ip_address" "this" {
  for_each = var.ips

  ip_address = each.value.address
  dns_name   = each.value.dns_name
  status     = "active"
}

output "site_id" {
  value = local.has_site ? netbox_site.this[0].id : null
}

output "prefix_id" {
  value = netbox_prefix.this.id
}
