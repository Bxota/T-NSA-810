# T-NSA-810 — Infrastructure as Code (CIA Réseau)

Infrastructure multi-sites automatisée sur Proxmox, déployée via Terraform + Ansible, avec gestion des secrets par Doppler.

## Architecture

```
Site 1 (10.1.0.0/24)          Site 2 (10.2.0.0/24)
┌─────────────────────┐        ┌─────────────────────┐
│  router_s1          │◄──────►│  router_s2          │
│  10.1.0.1           │  VPN   │  10.2.0.1           │
│                     │10.8.x  │                     │
│  netbox             │        │  bastion            │
│  10.1.0.10          │        │  10.2.0.5           │
│                     │        │                     │
│  elasticsearch      │        │  webserver          │
│  10.1.0.20          │        │  10.2.0.30          │
└─────────────────────┘        └─────────────────────┘
```

**6 VMs Ubuntu 24.04 LTS** réparties sur 2 hyperviseurs Proxmox :

| VM | IP | Rôle |
|----|----|------|
| router_s1 | 10.1.0.1 | VPN server, NAT, passerelle Site 1 |
| netbox | 10.1.0.10 | IPAM / DCIM (PostgreSQL + Gunicorn + Nginx) |
| elasticsearch | 10.1.0.20 | ELK stack (Elasticsearch + Kibana) |
| router_s2 | 10.2.0.1 | VPN client, NAT, passerelle Site 2 |
| bastion | 10.2.0.5 | Jump host SSH + endpoint OpenVPN externe |
| webserver | 10.2.0.30 | Serveur applicatif |

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
| VPN | OpenVPN (site-à-site + accès client) |
| Firewall | UFW + fail2ban |

## Prérequis

```bash
# Terraform
brew tap hashicorp/tap && brew install hashicorp/tap/terraform

# Doppler CLI
brew install dopplerhq/cli/doppler
doppler setup  # configurer avec le token du projet
```

Variables requises dans Doppler : `PROXMOX_S1_IP`, `PROXMOX_S2_IP`, `PROXMOX_PASSWORD`, `SSH_PRIVATE_KEY`, `NETBOX_SECRET_KEY`, `NETBOX_DB_PASSWORD`, `ELASTIC_PASSWORD`, `NETBOX_API_TOKEN`.

## Déploiement

### Bootstrap initial (une fois par site)

```bash
./deploy.sh bootstrap-s1    # bridge vmbr1 + template Ubuntu sur pve1
./deploy.sh bootstrap-s2    # bridge vmbr2 + template Ubuntu sur pve2
```

### Déploiement complet

```bash
./deploy.sh all
```

Équivalent de la chaîne complète :

```bash
./deploy.sh init              # terraform init
./deploy.sh netbox-bootstrap  # router_s1 + netbox + Ansible
./deploy.sh ipam              # peupler NetBox (sites, préfixes, IPs)
./deploy.sh infra             # déployer les 4 VMs restantes
./deploy.sh config            # configurer tous les services via Ansible
```

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

VPN client : importer `client.ovpn` dans OpenVPN pour accéder au réseau via le bastion.

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
│   │   └── vm-router/      # Module VM routeur (dual NIC)
│   └── netbox-ipam/        # Ressources IPAM (sites, préfixes, IPs)
└── ansible/
    ├── site.yml            # Playbook principal
    ├── inventory/
    │   └── hosts.yml
    ├── group_vars/
    │   └── all.yml
    └── roles/
        ├── common/         # Base OS (packages, SSH, NTP, UFW)
        ├── router/         # OpenVPN + NAT + forwarding
        ├── netbox/         # NetBox IPAM
        ├── elasticsearch/  # ELK stack
        ├── filebeat/       # Agent de logs
        ├── bastion/        # Jump host + VPN
        └── webserver/      # Serveur applicatif
```

## Supprimer le state Terraform

```bash
cd terraform/
terraform state list | xargs -I{} terraform state rm {}
```
