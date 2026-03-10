# TODO — Points temporaires à automatiser (GitOps)

## Infrastructure réseau (Proxmox)

- [ ] **Bridges vmbr1 / vmbr2** : créés manuellement sur le Proxmox enfant.
  Automatiser via cloud-init ou un script de provisionning Proxmox au bootstrap.

- [ ] **IP sur vmbr1/vmbr2** : `10.1.0.254/24` et `10.2.0.254/24` ajoutées manuellement.
  À intégrer dans la config réseau Proxmox (Netplan/interfaces) via un rôle Ansible ou
  un script de bootstrap.

- [ ] **NAT / IP forwarding sur Proxmox** : `iptables MASQUERADE` et `ip_forward=1` appliqués
  manuellement. À intégrer dans le bootstrap Proxmox (iptables-persistent + sysctl).
  Gateway temporaire : Proxmox (10.x.x.254) au lieu de pfSense (10.x.x.1).

- [ ] **Nested virtualization** : activée manuellement sur le Proxmox parent via
  `qm set <VMID> --cpu host`. À documenter comme prérequis ou automatiser via
  l'API Proxmox parent.

## Template Ubuntu

- [ ] **qemu-guest-agent absent du template** : installé via Ansible au runtime.
  Idéalement à intégrer dans le template via Packer pour éviter le `ignore_errors`
  dans le rôle common.

- [ ] **Agent Terraform désactivé** (`agent { enabled = false }`) : temporaire pour
  éviter le timeout de création. À repasser à `true` une fois qemu-guest-agent
  présent dans le template.

## Secrets Doppler

- [x] **Secrets Ansible configurés** : `NETBOX_SECRET_KEY`, `NETBOX_DB_PASSWORD`,
  `NETBOX_ADMIN_USER`, `NETBOX_ADMIN_PASSWORD`, `ELASTIC_PASSWORD`,
  `KIBANA_PASSWORD`, `OPENVPN_CA_PASS` tous définis dans Doppler.

## Services déployés

- [x] **NetBox** : opérationnel sur `http://10.1.0.10` (proxy nginx → gunicorn:8001).
  Migrations, collectstatic et superuser créés automatiquement via Ansible.

- [x] **Elasticsearch** : opérationnel sur `http://10.1.0.20:9200`.
  Sécurité xpack activée (sans SSL transport), mots de passe définis via Doppler.

- [x] **Kibana** : opérationnel sur `http://10.1.0.20:5601`.
  Connecté à Elasticsearch avec le compte `kibana_system`.

- [ ] **SSH known_hosts** : nettoyage automatique après `./deploy.sh infra` ajouté,
  mais à terme remplacer par un mécanisme de découverte dynamique des host keys
  (ex. enregistrement dans Vault/Doppler au provisioning).

## pfSense

- [ ] **pfSense non configuré** : les deux VMs pfsense_s1 et pfsense_s2 sont créées
  mais l'installation et la configuration (WAN/LAN, NAT, VPN) sont manuelles.
  À automatiser via l'API pfSense ou des scripts de bootstrap.
  Une fois configuré, repasser les gateways Terraform sur `10.1.0.1` / `10.2.0.1`.

## Accès aux services

- [ ] **Tunnels SSH manuels** : accès via `./tunnel.sh` (SSH -L vers Proxmox).
  À remplacer par un VPN (OpenVPN sur le bastion) pour un accès réseau direct
  et permanent au réseau interne.

## OpenVPN

- [x] **Port forwarding Proxmox** : automatisé via le rôle `proxmox-bootstrap`.
  DNAT UDP 1194 → bastion (10.2.0.5:1194), NAT masquerade pour site1/site2,
  ip_forward activé, règles persistées via iptables-persistent.

- [ ] **CA passphrase** : la CA OpenVPN est générée sans passphrase pour l'automatisation.
  Pour un environnement de production, utiliser `openvpn_ca_pass` (déjà dans Doppler)
  et gérer la passphrase dans Ansible Vault ou Doppler.
