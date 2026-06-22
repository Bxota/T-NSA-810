# T-NSA-810 — Infrastructure as Code (CIA Réseau)

Infrastructure multi-sites automatisée sur Proxmox, déployée via Terraform + Ansible, avec gestion des secrets par Doppler.

## Architecture

```
Site 1 (10.1.0.0/24)          Site 2 (10.2.0.0/24)
┌─────────────────────┐        ┌─────────────────────┐
│  pfsense_s1         │◄──────►│  pfsense_s2         │
│  10.1.0.1           │  VPN   │  10.2.0.1           │
│  (FW/VPN/DNS)       │10.8.x  │  (FW/VPN/DNS)       │
│  netbox             │        │  bastion            │
│  10.1.0.10          │        │  10.2.0.5           │
│                     │        │                     │
│  elasticsearch      │        │  webserver          │
│  10.1.0.20          │        │  10.2.0.30          │
└─────────────────────┘        └─────────────────────┘
```

**6 VMs Ubuntu 24.04 LTS + 2 pfSense** réparties sur 2 hyperviseurs Proxmox :

| VM | IP | Rôle |
|----|----|------|
| pfsense_s1 | 10.1.0.1 | Firewall + VPN server + NAT + DNS, passerelle Site 1 |
| netbox | 10.1.0.10 | IPAM / DCIM (PostgreSQL + Gunicorn + Nginx) |
| elasticsearch | 10.1.0.20 | ELK stack (Elasticsearch + Kibana) |
| pfsense_s2 | 10.2.0.1 | Firewall + VPN client + NAT + DNS, passerelle Site 2 |
| bastion | 10.2.0.5 | Jump host SSH + 2FA |
| webserver | 10.2.0.30 | Serveur applicatif interne |

## Stack technique

| Couche | Technologie |
|--------|-------------|
| Provisionnement VMs | Terraform (provider bpg/proxmox) |
| Configuration | Ansible |
| Secrets | Doppler |
| Hyperviseur | Proxmox VE |
| OS base | Ubuntu 24.04 LTS (cloud-init) |
| IPAM | NetBox 4.x |
| Logs | Elasticsearch 8.x + Kibana + Filebeat |
| Firewall / Routeur | pfSense (config.xml en IaC) |
| VPN | OpenVPN site-à-site (porté par pfSense) |
| DNS | Unbound (pfSense, forwarding inter-sites s1.local ↔ s2.local) |

## Prérequis

```bash
# Terraform
brew tap hashicorp/tap && brew install hashicorp/tap/terraform

# Doppler CLI
brew install dopplerhq/cli/doppler
doppler setup  # configurer avec le token du projet
```

Variables requises dans Doppler : `PROXMOX_S1_IP`, `PROXMOX_S2_IP`, `PROXMOX_ROOT_PASSWORD`, `SSH_PRIVATE_KEY`, `SSH_PUBLIC_KEY`, `NETBOX_SECRET_KEY`, `NETBOX_DB_PASSWORD`, `ELASTIC_PASSWORD`, `NETBOX_API_TOKEN`, `OPENVPN_SERVER_IP`, `PFSENSE_ADMIN_BCRYPT` (hash bcrypt du mot de passe admin pfSense), `PFSENSE_TEMPLATE_ID` (optionnel, défaut 9100).

## Déploiement

### Bootstrap initial (une fois par site)

```bash
./deploy.sh bootstrap-s1    # bridge vmbr1 + templates Ubuntu & pfSense sur pve1
./deploy.sh bootstrap-s2    # bridge vmbr2 + templates Ubuntu & pfSense sur pve2
```

> ⚠️ pfSense (FreeBSD, sans cloud-init) nécessite une **install console one-shot** par site
> avant de devenir un template réutilisable — voir [docs/runbooks/rebuild-full.md](docs/runbooks/rebuild-full.md) §2.

### Déploiement complet

```bash
./deploy.sh all
```

Équivalent de la chaîne complète :

```bash
./deploy.sh init              # terraform init
./deploy.sh netbox-bootstrap  # pfsense_s1 + netbox + Ansible
./deploy.sh ipam              # peupler NetBox (sites, préfixes, IPs)
./deploy.sh infra             # déployer les VMs restantes + pfsense_s2
./deploy.sh config            # configurer tous les services via Ansible
```

### Déconnexion d'urgence (kill switch)

```bash
./deploy.sh kill-switch all   # isole les deux sites (réversible)
./deploy.sh restore all       # rétablit la connectivité
```
Voir [docs/runbooks/kill-switch.md](docs/runbooks/kill-switch.md).

### Destruction

```bash
./deploy.sh destroy
```

## Accès aux services

```bash
./tunnel.sh    # SSH tunnels vers NetBox / Kibana via Proxmox
```

| Service | URL (après tunnel) |
|---------|-------------------|
| NetBox | http://localhost:8000 |
| Kibana | http://localhost:5601 |

Accès SSH direct (après déploiement) :

```bash
ssh -i /tmp/cia_infra cia@10.1.0.10   # netbox
ssh -i /tmp/cia_infra cia@10.2.0.5    # bastion
```

Le tunnel inter-sites est désormais géré en site-à-site par les deux pfSense (OpenVPN). Le
DNS interne résout les noms `*.s1.local` / `*.s2.local` de part et d'autre via le forwarding
Unbound configuré sur les pfSense.

## Structure du projet

```
.
├── deploy.sh               # Script d'orchestration principal
├── tunnel.sh               # Helper SSH tunnels
├── client.ovpn             # Config VPN client
├── scripts/
│   └── bootstrap-proxmox.sh
├── terraform/
│   ├── main.tf             # Définition des VMs
│   ├── netbox.tf           # VM NetBox
│   ├── locals.tf           # Source of truth des IPs
│   ├── modules/
│   │   ├── vm-linux/       # Module VM générique
│   │   └── vm-pfsense/     # Module VM pfSense (dual NIC, sans cloud-init)
│   └── netbox-ipam/        # Ressources IPAM (sites, préfixes, IPs)
└── ansible/
    ├── site.yml            # Playbook principal
    ├── inventory/
    │   └── hosts.yml
    ├── group_vars/
    │   └── all.yml
    └── roles/
        ├── common/         # Base OS (packages, SSH, NTP, UFW)
        ├── pfsense/        # Firewall/VPN/DNS pfSense (config.xml + kill switch)
        ├── netbox/         # NetBox IPAM
        ├── elasticsearch/  # ELK stack
        ├── filebeat/       # Agent de logs
        ├── bastion/        # Jump host + 2FA
        └── webserver/      # Serveur applicatif
```

## Documentation

| Doc | Contenu |
|-----|---------|
| [docs/DRP.md](docs/DRP.md) | Plan de reprise d'activité |
| [docs/runbooks/](docs/runbooks/) | Rebuild complet, restauration pfSense, kill switch |
| [docs/ecarts-justification.md](docs/ecarts-justification.md) | Justification des choix (pfSense, Doppler) |

## Supprimer le state Terraform

```bash
cd terraform/
terraform state list | xargs -I{} terraform state rm {}
```
