# Les ressources IPAM NetBox (sites, préfixes, adresses IP) sont gérées
# dans terraform/netbox-ipam/ — appliqué après le déploiement Ansible de NetBox.
#
# Les IPs sont définies dans locals.tf (source de vérité) et partagées
# entre ce module Proxmox et netbox-ipam/.
