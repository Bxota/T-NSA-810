# TODO — Dette technique & étapes encore manuelles

> État au 22 juin 2026. Le périmètre fonctionnel principal est livré (cf.
> [docs/etat-final.md](docs/etat-final.md)). Ce fichier liste ce qui reste manuel
> ou perfectible. Les items « faits » sont retirés et tracés dans etat-final.md.

## Infrastructure réseau (bootstrap Proxmox)

- [ ] **Bridges vmbr1 / vmbr2 (/vmbrN)** : créés manuellement sur les nodes Proxmox.
  À automatiser dans `scripts/bootstrap-proxmox.sh` (config réseau Netplan/interfaces).

- [ ] **Bootstrap node (NAT/forwarding sortant)** : la sortie internet du node et
  `ip_forward` restent posés au bootstrap manuel. Le NAT *inter-sites* est, lui,
  géré par pfSense. À intégrer entièrement au script de bootstrap.

- [ ] **Nested virtualization** : `--cpu host` activé manuellement sur l'hyperviseur
  parent. À documenter comme prérequis ou automatiser via l'API Proxmox parent.

## Template Ubuntu

- [ ] **qemu-guest-agent absent du template** : installé via Ansible au runtime.
  Idéalement intégré au template via Packer (évite le `ignore_errors` du rôle common).

- [ ] **Agent Terraform désactivé** (`agent { enabled = false }`) : à repasser à `true`
  une fois qemu-guest-agent présent dans le template.

- [ ] **Template ubuntu (9000) à restaurer sur pve4** : supprimé pour libérer le thin
  pool (io-error). Le reconstruire via `./deploy.sh bootstrap-s1` après agrandissement
  disque. Le template pfSense (9100) a, lui, été restauré depuis le vzdump.

## Capacité / stockage

- [ ] **Thin pool pve4/pve5 tendu** (~90 %) : sur-provisionnement. Agrandir le disque
  des nodes puis `pvresize` + `lvextend -l +100%FREE pve/data`. Ensuite passer le
  disque de la VM Elasticsearch à 50 Go.

## Accès aux services

- [ ] **Tunnels SSH manuels** : accès via `./tunnel.sh` (SSH -L vers Proxmox). À
  remplacer par un accès VPN client permanent au réseau interne (ex. OpenVPN sur le
  bastion, en plus du site-à-site pfSense existant).

## Sécurité

- [ ] **CA OpenVPN sans passphrase** : générée sans passphrase pour l'automatisation.
  En production, utiliser `openvpn_ca_pass` (déjà dans Doppler) via Ansible Vault/Doppler.

- [ ] **SSH known_hosts** : nettoyage automatique après `./deploy.sh infra`, mais à
  terme prévoir une découverte dynamique des host keys.

## Bonus restants (cf. etat-final.md)

- [ ] **CD automatisé** : `deploy.sh` reste déclenché manuellement (lint + tests CI déjà en place).
- [ ] **Log parsing structuré** : logs expédiés bruts ; les modules Filebeat (system/nginx)
  n'ont pas abouti sur cet environnement — à reprendre (ingest pipelines / Logstash grok).
