# ══════════════════════════════════════════════════════════════════════════════
# Source de vérité des adresses IP
# Ces valeurs alimentent à la fois les VMs Proxmox et le plan IPAM NetBox
# (terraform/netbox-ipam/)
# ══════════════════════════════════════════════════════════════════════════════

locals {
  ip = {
    pfsense_s1    = "10.1.0.1/24"
    netbox        = "10.1.0.10/24"
    elasticsearch = "10.1.0.20/24"
    pfsense_s2    = "10.2.0.1/24"
    bastion       = "10.2.0.5/24"
    webserver     = "10.2.0.30/24"
  }

  gw = {
    s1 = split("/", local.ip.pfsense_s1)[0]
    s2 = split("/", local.ip.pfsense_s2)[0]
  }
}
