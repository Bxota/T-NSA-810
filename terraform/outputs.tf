output "pfsense_s1_name" { value = module.pfsense_s1.vm_name }
output "netbox_ip" { value = "10.1.0.10" }
output "elasticsearch_ip" { value = "10.1.0.20" }
output "pfsense_s2_name" { value = module.pfsense_s2.vm_name }
output "bastion_ip" { value = "10.2.0.5" }
output "webserver_ip" { value = "10.2.0.30" }
