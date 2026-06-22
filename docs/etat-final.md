# État final du projet — T-NSA-810 (CIA / Proxmox hybride)

_Document de livraison. Mappe chaque exigence du sujet à son implémentation et à
la preuve correspondante dans le dépôt._

## Couverture des exigences client

| Exigence (sujet) | État | Implémentation / preuve |
|---|---|---|
| Infra hybride Proxmox S1 + S2 | ✅ | `terraform/main.tf` — 6 VMs + 2 pfSense sur 2 nœuds (pve4/pve5) |
| VPN site-à-site sécurisé | ✅ | OpenVPN p2p_tls porté par pfSense, PKI dédiée, `iroute` pour le routage des LAN distants (`roles/pfsense/templates/config.xml.j2`) |
| Firewall sur les deux sites | ✅ | pfSense, `config.xml` deny-by-default + règles par flux |
| Déconnexion d'urgence (kill switch) | ✅ | `roles/pfsense/templates/kill-switch.sh.j2`, `deploy.sh kill-switch` / `restore`, runbook dédié |
| Bastion d'accès distant | ✅ | `roles/bastion` — SSH durci + 2FA `google-authenticator` + fail2ban |
| IPAM (NetBox) | ✅ | `roles/netbox` + `terraform/netbox-ipam` (sites, préfixes, IPs) |
| IPAM mis à jour automatiquement | ✅ | `roles/netbox_sync` — timer systemd, sync API Proxmox → NetBox toutes les 15 min |
| Observabilité (logs centralisés) | ✅ | Elasticsearch + Kibana + Filebeat sur les **6 VMs** (Site 2 via le VPN) |
| Dashboards / analyse | ✅ | Dashboard Kibana « CIA — Observabilité Infrastructure » versionné en IaC |
| Site web interne uniquement | ✅ | `roles/webserver` — exposé seulement sur le LAN/VPN, jamais sur le WAN (aucun port-forward) |
| DNS forwarding inter-sites | ✅ | Unbound pfSense — host overrides + domain override `s1.local` ↔ `s2.local` |
| Séparation des flux | ✅ | LAN par site, tunnel VPN dédié, règles firewall par interface |
| Tout en IaC | ✅ | Terraform + Ansible (8 rôles) + `deploy.sh`, secrets Doppler |
| Stockage sécurisé des secrets | ✅ | Doppler (injection par env, aucun secret en clair dans le repo) |
| Documentation reproductible | ✅ | `readme.md`, `docs/DRP.md`, `docs/runbooks/` |
| DRP + runbooks | ✅ | `docs/DRP.md`, `docs/runbooks/` (rebuild complet, restauration pfSense, kill switch, install pfSense) |

## Bonus

| Bonus | État | Preuve |
|---|---|---|
| CI/CD — lint IaC | ✅ | `.github/workflows/lint.yml` (terraform, ansible, shell, python) |
| Multi-site (scalabilité) | ✅ | Convention d'adressage par site (10.X.0.0/24), rôles paramétrés par `router_role` ; ajout d'un site = nouveau bloc Terraform + entrées inventaire |
| Monitoring avancé (dashboards) | ✅ | Dashboard Kibana provisionné automatiquement |

## Validation fonctionnelle (dernière vérification)

| Test | Résultat |
|---|---|
| Tunnel VPN inter-sites (ping S2 → 10.1.0.1) | 0 % perte, ~1 ms |
| Routage LAN distant (webserver S2 → ES S1, HTTP) | HTTP 200 |
| Filebeat — logs des 4 VMs applicatives dans ES | netbox, elastic, web, bastion présents |
| Dashboard Kibana | importé (7 objets), data view résolu |
| IPAM auto-sync | 6 VMs synchronisées, timer `active`, run systemd `status=0` |

## Écarts assumés

Voir [ecarts-justification.md](ecarts-justification.md) :
- **Vault → Doppler** pour la gestion des secrets.
- Détails d'implémentation pfSense (config.xml en IaC plutôt que clic-à-clic).
