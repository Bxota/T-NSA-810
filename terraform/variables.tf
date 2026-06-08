variable "PROXMOX_API_URL"      { type = string }
variable "PROXMOX_TOKEN_ID"     { type = string }
variable "PROXMOX_TOKEN_SECRET" {
  type      = string
  sensitive = true
}
variable "SSH_PUBLIC_KEY"  { type = string }
variable "SSH_PRIVATE_KEY" {
  type      = string
  sensitive = true
}
variable "VM_USER"     { default = "cia" }
variable "VM_PASSWORD" {
  type      = string
  sensitive = true
}
variable "TARGET_NODE" { default = "pve" }
variable "STORAGE"     { default = "local" }
variable "TEMPLATE_ID" {
  type    = number
  default = 9000
}
