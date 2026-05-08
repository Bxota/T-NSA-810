variable "netbox_url" {
  type    = string
  default = "http://10.1.0.10"
}

variable "netbox_token" {
  type      = string
  sensitive = true
}

# ── IPs — doivent correspondre à terraform/locals.tf ─────────────────────────

variable "ip_router_s1_lan" {
  type    = string
  default = "10.1.0.1/24"
}

variable "ip_netbox" {
  type    = string
  default = "10.1.0.10/24"
}

variable "ip_elasticsearch" {
  type    = string
  default = "10.1.0.20/24"
}

variable "ip_router_s2_lan" {
  type    = string
  default = "10.2.0.1/24"
}

variable "ip_bastion" {
  type    = string
  default = "10.2.0.5/24"
}

variable "ip_webserver" {
  type    = string
  default = "10.2.0.30/24"
}
