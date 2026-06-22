# Analyse d'avancement — T-NSA-810 (CIA / Proxmox hybride)

_Analyse au 8 juin 2026._

## Où en est le projet

Le planning (Gantt) place la livraison finale (**Keynote**) au **14 juin 2026**. Nous sommes
donc à **~6 jours du rendu final**, en pleine phase « Keynote — Final Delivery ».

Réalité du code vs planning : les briques d'infrastructure sont en place (le dernier commit
fonctionnel — IPAM NetBox — date du **8 mai**), mais le travail de code s'est largement
arrêté il y a un mois. Plusieurs exigences explicites du client restent ouvertes
(firewall/hardening, DNS forwarding, kill switch, DRP). En résumé : **l'ossature « beta »
est atteinte, mais les livrables de la phase finale ne le sont pas encore.**

Estimation globale : **~70 % du périmètre fonctionnel**, mais des manques portent
directement sur des critères d'évaluation notés.

## Ce qui est fait ✅

| Exigence client | État | Détail |
|---|---|---|
| Infra hybride Proxmox S1 + S2 | ✅ | Terraform provisionne 6 VMs Ubuntu 24.04 sur 2 nodes (`vm-linux`, `vm-router`) |
| VPN site-à-site | ✅ | Rôle `router` complet : PKI easy-rsa, serveur (S1) / client (S2), tunnel 10.8.0.0/24, routes inter-sites |
| Bastion d'accès externe | ✅ | SSH durci, 2FA `google-authenticator`, `fail2ban`, `auditd` |
| IPAM NetBox | ✅ | Déployé (nginx+gunicorn+PostgreSQL) **et** peuplé via Terraform (`netbox-ipam` : sites, préfixes, IPs) |
| Observabilité | ✅ | Elasticsearch 8.x + Kibana + Filebeat (xpack activé) |
| Stockage de secrets | ✅* | Doppler (toutes les clés injectées via env). *Le kickoff mentionnait Vault — voir écarts.* |
| Tout en IaC | ✅ | Terraform + Ansible (7 rôles) + orchestrateur `deploy.sh` |
| Repo GitOps | ✅ | Plusieurs branches (`main`, `IAC_thomas`, `IAC_mohamed`, `thomas/poc`…) |
| Gantt + backlog + schémas | ✅ | `gantt.html`, `infra_V3.drawio/png`, `TODO.md` |

## Ce qui manque ou est partiel ⚠️

| Exigence client / livrable | État | Risque |
|---|---|---|
| **Firewall pfSense** | ❌ | Le sujet impose **pfSense** comme firewall. Pivot vers routeur Linux + iptables : pas de pfSense déployé. **UFW est installé mais aucune règle/deny-by-default n'est configurée.** Critère noté : « sécurité et efficacité des configs firewall ». |
| **Déconnexion d'urgence (kill switch)** | ❌ | Aucune implémentation trouvée. Exigence explicite du client. |
| **DNS forwarding inter-sites** | ❌ | `dnsmasq` est installé sur les routeurs mais **sans config, sans zone, sans forwarding**. Exigence client non remplie. |
| **IPAM mis à jour automatiquement** | ⚠️ | NetBox est peuplé **statiquement** via Terraform. Pas de script de synchro Proxmox → NetBox (la tâche « NetBox auto-update » du Gantt n'est pas faite). |
| **Site web interne uniquement** | ⚠️ | nginx écoute sur `:80` sans restriction ; l'isolement repose uniquement sur la topologie (pas d'IP publique), pas de règle firewall explicite. |
| **DRP / runbooks** | ❌ | Aucun document de reprise après sinistre ni runbook de rebuild. Livrable Keynote obligatoire. |
| **CI/CD (bonus)** | ❌ | Pas de `.github/workflows` (lint/validate IaC). |
| **Automatisations manuelles** (TODO.md) | ⚠️ | Bridges Proxmox, IP vmbr1/2, NAT/forward, nested virt, qemu-guest-agent, gateways encore sur Proxmox au lieu des routeurs : tout encore manuel. Accès via tunnels SSH au lieu d'un VPN client permanent. |

## Écarts notables par rapport au sujet

- **pfSense → routeur Linux** : le firewall imposé (pfSense) a été remplacé par des VMs
  routeur Linux (OpenVPN + iptables). Choix défendable techniquement, mais à **justifier
  explicitement** car c'est une contrainte du sujet et un critère d'évaluation. `archi.txt`
  et le Gantt référencent encore pfSense — documentation incohérente avec le code réel.
- **Vault → Doppler** : le kickoff cite Vault ; Doppler est un gestionnaire de secrets
  valide, mais l'écart est à justifier (le livrable Keynote demande une « database de
  credentials sécurisée »).

## Priorités recommandées avant le 14 juin

Par ordre d'impact sur la note :

1. **Durcir le firewall** : configurer UFW deny-by-default + règles par flux sur chaque VM
   (ou assumer et documenter pleinement le choix pfSense vs iptables). C'est le critère le
   plus exposé.
2. **DNS forwarding inter-sites** : finaliser la config `dnsmasq` (zones `s1.local`/`s2.local`,
   forwarding réciproque) — exigence client encore à zéro.
3. **Kill switch** : implémenter une coupure d'urgence (ex. règle iptables / script de
   désactivation du tunnel) réversible.
4. **DRP + runbooks** : rédiger la doc de reprise et la procédure de rebuild (livrable Keynote).
5. **Justifier les écarts** (pfSense, Vault) dans le document technique.
6. Bonus si temps : script de synchro NetBox, CI lint IaC, restriction firewall explicite du web interne.
