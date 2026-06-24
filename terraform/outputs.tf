output "pfsense" {
  description = "Nom des VMs pfSense par site"
  value       = { for k, m in module.pfsense : k => m.vm_name }
}

output "vms" {
  description = "Nom des VMs applicatives par site-service"
  value       = { for k, m in module.vm : k => m.vm_name }
}
