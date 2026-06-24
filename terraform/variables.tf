# ── Accès cluster Proxmox (un seul jeu : le cluster gère tous les noeuds) ─────
variable "proxmox_api_url" { type = string }
variable "proxmox_token_id" { type = string }
variable "proxmox_token_secret" {
  type      = string
  sensitive = true
}

# ── Commun VMs ───────────────────────────────────────────────────────────────
variable "ssh_public_key" { type = string }
variable "vm_user" { default = "cia" }
variable "vm_password" {
  type      = string
  sensitive = true
}
variable "storage" { default = "local-lvm" }

# ── Définition des sites — AJOUTER UN SITE = AJOUTER UNE ENTRÉE ───────────────
# La topologie réelle est dans sites.auto.tfvars (chargé automatiquement).
variable "sites" {
  type = map(object({
    node             = string # noeud Proxmox hôte du site
    lan_bridge       = string # bridge LAN (vmbr1, vmbr2, …)
    gateway          = string # IP LAN du pfSense = gateway des VMs
    pfsense_vmid     = number
    pfsense_template = number # VMID du template pfSense sur ce noeud
    ubuntu_template  = number # VMID du template Ubuntu sur ce noeud
    vms = map(object({
      vmid   = number
      cores  = number
      memory = number
      disk   = number
      ip     = string # ex: "10.1.0.10/24"
    }))
  }))
}
