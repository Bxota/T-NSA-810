variable "proxmox_api_url"      { type = string }
variable "proxmox_token_id"     { type = string }
variable "proxmox_token_secret" {
  type      = string
  sensitive = true
}
variable "ssh_public_key"       { type = string }
variable "vm_user"              { default = "cia" }
variable "vm_password"          {
  type      = string
  sensitive = true
}
variable "target_node"          { default = "pve" }
variable "storage"              { default = "local-lvm" }
variable "template_id"          { type = number }
