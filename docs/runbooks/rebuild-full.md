# Runbook — Reconstruction complète de l'infrastructure

Reconstruit l'intégralité des deux sites depuis zéro. Durée indicative : 3-4 h.

## Prérequis
- Accès aux deux Proxmox (IP + mot de passe root dans Doppler).
- `doppler`, `terraform`, `ansible`, `sshpass` installés sur la machine de déploiement.
- Dépôt Git cloné, session Doppler active (`doppler login` + `doppler setup`).

## Étapes

### 1. Bootstrap des hyperviseurs (bridges + templates)
```bash
./deploy.sh bootstrap-s1   # vmbr1 + template Ubuntu + template pfSense (pve1)
./deploy.sh bootstrap-s2   # vmbr2 + template Ubuntu + template pfSense (pve2)
```

### 2. Install pfSense one-shot (préalable manuel, par site)
Le template pfSense est créé en VM bootant sur l'ISO. **Une seule fois** par site :
```bash
# Sur le Proxmox concerné :
qm terminal 9100          # installer pfSense (Install → ZFS/UFS → reboot)
# Puis détacher l'ISO et convertir en template :
qm set 9100 --ide2 none --boot order=scsi0
qm template 9100
```
> Pendant l'install console : ne pas configurer d'interfaces ni de VLAN, l'IP LAN et
> toute la conf sont injectées ensuite par Ansible via `config.xml`. Activer SSH si proposé.

### 3. Terraform init
```bash
./deploy.sh init
```

### 4. Amorçage NetBox (gateway S1 + IPAM)
```bash
./deploy.sh netbox-bootstrap   # pfsense_s1 + VM NetBox, puis Ansible pfsense_s1 → netbox
./deploy.sh ipam               # peuple NetBox (sites, préfixes, IPs)
```

### 5. Provisionnement des VMs + pfSense S2
```bash
./deploy.sh infra              # 6 VMs applicatives + pfsense_s2
```

### 6. Configuration de tous les services
```bash
./deploy.sh config             # pfSense (FW/VPN/DNS) + netbox + elastic + bastion + web
```

> Raccourci : `./deploy.sh all` enchaîne les étapes 1, 3, 4, 5, 6 (l'install pfSense
> one-shot de l'étape 2 reste manuelle si les templates pfSense n'existent pas encore).

## Vérification
Voir [../DRP.md](../DRP.md) §5 (tunnel VPN, DNS inter-sites, firewall, services).
