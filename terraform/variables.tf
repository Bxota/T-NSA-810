# ── Proxmox Site 1 ───────────────────────────────────────────────────────────
variable "proxmox_s1_api_url" { type = string }
variable "proxmox_s1_token_id" { type = string }
variable "proxmox_s1_token_secret" {
  type      = string
  sensitive = true
}
variable "proxmox_s1_node" { default = "pve" }

# ── Proxmox Site 2 ───────────────────────────────────────────────────────────
variable "proxmox_s2_api_url" { type = string }
variable "proxmox_s2_token_id" { type = string }
variable "proxmox_s2_token_secret" {
  type      = string
  sensitive = true
}
variable "proxmox_s2_node" { default = "pve" }

# ── VM commun ────────────────────────────────────────────────────────────────
variable "ssh_public_key" { type = string }
variable "vm_user" { default = "cia" }
variable "vm_password" {
  type      = string
  sensitive = true
}
variable "storage" { default = "local-lvm" }

# ── Templates ────────────────────────────────────────────────────────────────
variable "s1_template_id" {
  type    = number
  default = 9000
}
variable "s2_template_id" {
  type    = number
  default = 9000
}
