// infra variables: node, storage, bridge, template
variable "proxmox_api_url" {
  description = "Proxmox API endpoint URL"
  type        = string
}

variable "proxmox_api_token" {
  description = "Proxmox API token in the form user@realm!tokenid=secret"
  type        = string
  sensitive   = true
}

variable "proxmox_insecure" {
  description = "Skip TLS certificate validation for lab envs"
  type        = bool
  default     = true
}

variable "target_node" {
  description = "Target Proxmox node for site 1"
  type        = string
  default     = "pve2"
}

variable "storage_name" {
  description = "Storage for VM disks"
  type        = string
  default     = "local-lvm"
}

variable "site1_bridge" {
  description = "Bridge used for Site 1 internal network"
  type        = string
  default     = "vmbr1"
}

variable "template_vm_id" {
  description = "Ubuntu template VM to clone from"
  type        = number
  default     = 9000
}

/*-----------------------------------------*/
// ADDING VARIABLES FOR TEST VM

variable "netbox_vm_id" {
  type    = number
  default = 411
}

variable "netbox_name" {
  type    = string
  default = "cia-netbox-tf"
}

variable "netbox_ip" {
  type    = string
  default = "10.1.0.11/24"
}

variable "gateway" {
  type    = string
  default = "10.1.0.1"
}